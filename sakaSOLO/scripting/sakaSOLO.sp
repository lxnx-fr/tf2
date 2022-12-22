#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <multicolors>
#include <tf2>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#define PLUGIN_VERSION 		"1.3"
#define PLUGIN_NAME 		"sakaSOLO"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Take on the other team solely (Intended for dodgeball)."
#define PLUGIN_URL 			"https://tf2.l03.dev/"

#define COMMAND_COOLDOWN    1 // In Seconds

Handle hRedQueue = INVALID_HANDLE;
Handle hBlueQueue = INVALID_HANDLE;
Handle hNoPreferenceQueue = INVALID_HANDLE;

/**
 * KNOWN BUGS: 
 * ###Example###
 * 3 Players in Team Red, 1 Bot in Team Blue
 * Player 1: Enabled Solo Mode vs Enemy Team (RedQueue)
 * Player 2: Enabled Solo Mode vs All (NoPrefQueue)
 * Player 3: No Solo Mode activated
 * 
 * On Death of Player 3
 * -> Respawn First Client of Team Queue (Red/Blue) (If there is a Player in the Team Queue)
 * -> Otherwise Respawn First Client of NoPref Queue (If there is a Player in the Team Queue)
 * 
 * On Death of Player 1:
 * -> Respawn Next Client of Team Queue (Red/Blue) (If there is another Player in the Team Queue)
 * -> Otherwise Respawn Next Client of NoPref Queue (If there is another Player in the NoPref Queue)
 * 
 * 
 * On Client Disconnect of Player 3 
 * -> ###AFTER DISCONNECT CHECK###
 * -> If Every Player of the Team (Red/Blue) has Solo Mode Activated (Red/Blue/NoPref Queue)
 * -> Respawn First Player of the Team Queue (Red/Blue) (If there is a Player in the Team Queue) (and Remove him from the Queue)
 * -> Otherwise Respawn First Client of the NoPref Queue (If there is a Player in the NoPref Queue) (and Remove him from the Queue)
 * 
 * -> ###NEXT ROUND SETUP/START CHECK###
 * -> If Every Player of the Team (Red/Blue) has Solo Mode Activated (Red/Blue/NoPref Queue)
 * -> Disable Solo Mode on First Client of the Team SoloQueue
 * -> Otherwise Disable Solo mode on First Client of the NoPref SoloQueue
 */

bool bMapChanged;
bool bRoundStarted;
int iLastRespawnTime;
int iLastRespawnedClient;

enum struct SoloInfo {
    bool bSoloMode;
    bool bAnyTeam;
    bool bHasRespawned;
    bool bCanSoloCommand;
    bool bNoDamage;
    int iDeaths;
    int iTeam;
    int iLastUsed;
}
SoloInfo SoloPlayer[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart() {
    PrintToServer("[sakaSOLO] Enabling Plugin (Version %s)", PLUGIN_VERSION);
    LoadTranslations("sakasolo.phrases.txt");
    RegConsoleCmd("sm_solo", SoloCommand, "Enable/disable solo modes via a menu.");
    hRedQueue = CreateArray();
    hBlueQueue = CreateArray();
    hNoPreferenceQueue = CreateArray();
    HookEvent("player_death", PlayerDeathEvent, EventHookMode_Pre);
    HookEvent("arena_round_start", RoundStartEvent, EventHookMode_Post);
    HookEvent("player_team", PlayerTeamEvent);
    HookEvent("arena_win_panel", RoundEndEvent);
    HookEvent("teamplay_round_start", RoundSetupEvent, EventHookMode_Pre);
    /**
     * Just for development mode
     */
    for (int iClient = 1; iClient <= MaxClients; iClient++) {
        if (IsClientConnected(iClient)) {
            SoloPlayer[iClient].bAnyTeam = false;
            SoloPlayer[iClient].bCanSoloCommand = true;
            SoloPlayer[iClient].bHasRespawned = false;
            SoloPlayer[iClient].iDeaths = 0;
            SoloPlayer[iClient].iTeam = 0;
            SoloPlayer[iClient].bNoDamage = false;
            SoloPlayer[iClient].iLastUsed = 0;
        }
    }
}
public void OnPluginEnd() {
    PrintToServer("[sakaSOLO] Disabling Plugin");
}


/**
 * Some Basic Events
 */
public void OnClientPutInServer(int iClient) {
    /**
     * Reset every settings on join
     */
    SoloPlayer[iClient].bAnyTeam = false;
    if (!bRoundStarted)
        SoloPlayer[iClient].bCanSoloCommand = true;
    SoloPlayer[iClient].bHasRespawned = false;
    SoloPlayer[iClient].iDeaths = 0;
    SoloPlayer[iClient].iTeam = 0;
    SoloPlayer[iClient].bNoDamage = false;
    SoloPlayer[iClient].iLastUsed = 0;
}
public void OnClientDisconnect(int iClient) {
    /**
     * If Client is Connected & is a Bot -> Cancel
     */
    if (IsClientConnected(iClient) && IsFakeClient(iClient)) return;
    /**
     * If Client is not In Game -> Cancel
     */
    if (!IsClientInGame(iClient)) return;
    /**
     * If Client is in Team Red/Blue/NoPref Queue, remove him from Solo queue
     */
    if (IsPlayerInAnyTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hNoPreferenceQueue, iIndex);
    } else if (IsPlayerInBlueTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
    } else if (IsPlayerInRedTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
    } else {
        /**
         * If player was not in Queue and Rest of the Team is in Solo
         */
        int iTeam = SoloPlayer[iClient].iTeam;
        if (IsRestOfTeamInSoloQueue(iTeam)) {
            if (iTeam == 2) {
                /**
                 * If Team is Red/Blue, get the first Client to respawn, because the last alive client that was not in queue disconnected
                 */
                int iFirstClient = -1;
                /**
                 * If Solo Queue from Red has players, take first from Red Queue
                 */
                if (GetArraySize(hRedQueue) > 0) {
                    iFirstClient = GetClientOfUserId(GetArrayCell(hRedQueue, 0));
                /**
                 * If Solo Queue from Red is empty, take first from NoPref Queue
                 */
                } else if (GetArraySize(hNoPreferenceQueue) > 0) {
                    iFirstClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, 0));
                /**
                 * If No Queue Player was found -> Cancel
                 */
                } else return;
                if (GetClientTeam(iClient) != 2) {
                    TF2_ChangeClientTeam(iFirstClient, TFTeam_Red);
                }
                /**
                 * If Solo Queue Player was found and hasn't been respawned yet
                 * -> Respawn First Player
                 */
                if (iFirstClient != -1 && !SoloPlayer[iFirstClient].bHasRespawned) {
                    TF2_RespawnPlayer(iFirstClient);
                    SoloPlayer[iFirstClient].bHasRespawned = true;
                    iLastRespawnTime = GetGameTickCount();
                    iLastRespawnedClient = iFirstClient;
                    SDKHook(iFirstClient, SDKHook_OnTakeDamage, OnTakeDamage);
                    SoloPlayer[iFirstClient].bNoDamage = true;
                    ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
                    /**
                     * Because last alive player disconnected, respawned client got removed from queue
                     */
                    CreateTimer(1.0, RemoveFromQueueTimer, iClient);
                }
            } else if (iTeam == 3) {
                int iFirstClient = -1;
                /**
                 * If Solo Queue from Blue has players, take first from Blue Queue
                 */
                if (GetArraySize(hBlueQueue) > 0) {
                    iFirstClient = GetClientOfUserId(GetArrayCell(hBlueQueue, 0));
                /**
                 * If Solo Queue from Blue is empty, take first from NoPref Queue
                 */
                } else if (GetArraySize(hNoPreferenceQueue) > 0) {
                    iFirstClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, 0));
                /**
                 * If No Queue Player was found -> Cancel
                 */
                } else return;
                if (GetClientTeam(iClient) != 3) {
                    TF2_ChangeClientTeam(iFirstClient, TFTeam_Blue);
                }
                /**
                 * If Solo Queue Player was found and hasn't been respawned yet
                 * -> Respawn First Player
                 */
                if (iFirstClient != -1 && !SoloPlayer[iFirstClient].bHasRespawned) {
                    TF2_RespawnPlayer(iFirstClient);
                    SoloPlayer[iFirstClient].bHasRespawned = true;
                    iLastRespawnTime = GetGameTickCount();
                    iLastRespawnedClient = iFirstClient;
                    SDKHook(iFirstClient, SDKHook_OnTakeDamage, OnTakeDamage);
                    SoloPlayer[iFirstClient].bNoDamage = true;
                    ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
                    CreateTimer(1.0, RemoveFromQueueTimer, iClient);
                }
            }
        }      
    } 
}
public void OnMapEnd() {
    bMapChanged = true;
}
public void OnMapStart() {
    /**
     * Clear all Queue's and reset some settings
     */
    ClearArray(hRedQueue);
    ClearArray(hBlueQueue);
    ClearArray(hNoPreferenceQueue);
    CreateTimer(10.0, MapStartTimer);
    bRoundStarted = false;
    iLastRespawnedClient = 0;
    iLastRespawnTime = 0;
}
/**
 * Commands & Menus
 */
public void DrawSoloMenu(int iClient) {
    Menu menu = new Menu(SoloMenuHandle);
    menu.SetTitle("Choose your Solo Mode");
    menu.AddItem("0", "Solo vs Enemy Team");
    menu.AddItem("1", "Solo vs All");
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}
public int SoloMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            switch (iItem) {
                case 0: { AddToEnemyTeamQueue(iClient); }
                case 1: { AddToAnyTeamQueue(iClient); }
            }
        }
        case MenuAction_End: { delete menu; }
    }
    return 0;
}
public Action SoloCommand(int iClient, int iArgs) {
    /**
     * Display Basic Plugin Informations
     */
    if (iArgs == 1) {
        char sArgOne[32];
        GetCmdArg(1, sArgOne, sizeof(sArgOne));
        if (StrEqual(sArgOne, "info", false)) {
            CReplyToCommand(iClient, "{mediumpurple}sᴏʟᴏ {black}» {default}Solo System rewritten by {dodgerblue}ѕαĸα {default}(Version {dodgerblue}%s{default})", PLUGIN_VERSION);
            CReplyToCommand(iClient, "{mediumpurple}sᴏʟᴏ {black}» {default}Commands:");
            CReplyToCommand(iClient, "{mediumpurple}sᴏʟᴏ {black}» {default}/solo - Open Solo Menu");
        }
    }
    /**
     * If Client is not InGame -> Cancel
     */
    if (!IsClientInGame(iClient)) return Plugin_Handled;
    
    /**
     * If Client has Command Cooldown -> Cancel
     */
    int iCurrentTime = GetTime();
    if ((iCurrentTime - SoloPlayer[iClient].iLastUsed) < COMMAND_COOLDOWN) {
        CPrintToChat(iClient, "%t", "Command_Solo_Cooldown", COMMAND_COOLDOWN - (iCurrentTime - SoloPlayer[iClient].iLastUsed));
        return Plugin_Handled;
    }
    SoloPlayer[iClient].iLastUsed = GetTime();
    /**
     * If Client Team is not Red or Blue -> Cancel
     */
    int iTeam = GetClientTeam(iClient);
    if (iTeam == 1 || iTeam == 0) {
        CPrintToChat(iClient, "%t", "Command_Solo_OnlyRedBlueTeam");
        return Plugin_Handled;
    }
    /**
     * If Client is not in Solo Mode -> Open Solo Menu
     */
    if (!SoloPlayer[iClient].bSoloMode) {
        /**
         * If Client can't execute Solo Command, is Observer or Round Started -> Cancel
         */
        if (!SoloPlayer[iClient].bCanSoloCommand || IsClientObserver(iClient) || bRoundStarted) {
            CPrintToChat(iClient, "%t", "Command_Solo_NotUseRightNow");
            return Plugin_Handled;
        }
        /**
         * If Rest of the Team is in Solo Queue -> Cancel
         */
        if (IsRestOfTeamInSoloQueue(iTeam)) {
            CPrintToChat(iClient, "%t", "Command_Solo_RestOfTeamInSolo");
            return Plugin_Handled;
        }
        DrawSoloMenu(iClient);
    } else {
        /**
         * If Client has Any Team Solo Mode: Remove Client from NoPref Queue
         * Else: Remove Client from Red / Blue Team Queue
         */
        if (IsPlayerInAnyTeamQueue(iClient)) {
            int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hNoPreferenceQueue, iIndex);
        } else {
            if (IsPlayerInRedTeamQueue(iClient)) {
                int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            } else if (IsPlayerInBlueTeamQueue(iClient)) {
                int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            } else {
                PrintToServer("[sakaSOLO] Team / Queue not found %i for %N", SoloPlayer[iClient].iTeam, iClient);
            }
        }
        /**
         * Reset some basic Settings
         */
        SoloPlayer[iClient].bSoloMode = false;
        SoloPlayer[iClient].bAnyTeam = false;
        SoloPlayer[iClient].bHasRespawned = false;
        SoloPlayer[iClient].bNoDamage = false;
        SoloPlayer[iClient].iDeaths = 0;
        CPrintToChat(iClient, "%t", "Command_Solo_Deactivated", iClient);
    }
    return Plugin_Handled;
}
/**
 * Basic Functions
 */
public void AddToAnyTeamQueue(int iClient) {
    int iCurrentTeam = GetClientTeam(iClient);
    /**
      * If Client can't execute Solo Command, is Observer or Round Started -> Cancel
      */
    if (!SoloPlayer[iClient].bCanSoloCommand || IsClientObserver(iClient) || bRoundStarted) {
        CPrintToChat(iClient, "%t", "Command_Solo_NotUseRightNow");
        return;
    }
    /**
     * If Client Team is not Red or Blue -> Cancel
     */
    if (iCurrentTeam == 1 || iCurrentTeam == 0) {
        CPrintToChat(iClient, "%t", "Command_Solo_OnlyRedBlueTeam");
        return;
    }
    /**
      * If Rest of the Team is in Solo Queue -> Cancel
      */
    if (IsRestOfTeamInSoloQueue(iCurrentTeam)) {
        CPrintToChat(iClient, "%t", "Command_Solo_RestOfTeamInSolo");
        return;
    }
    /**
     * If Client is alive, force suicide
     */
    if (IsPlayerAlive(iClient)) { ForcePlayerSuicide(iClient); }
    /**
     * Add Client to Solo Queue
     */
    PushArrayCell(hNoPreferenceQueue, GetClientUserId(iClient));
    SoloPlayer[iClient].bSoloMode = true;
    SoloPlayer[iClient].bAnyTeam = true;
    SoloPlayer[iClient].bHasRespawned = false;
    SoloPlayer[iClient].iTeam = iCurrentTeam;
    CPrintToChat(iClient, "%t", "Command_Solo_Activated", iClient);
}
public void AddToEnemyTeamQueue(int iClient) {
    int iCurrentTeam = GetClientTeam(iClient);
    /**
      * If Client can't execute Solo Command, is Observer or Round Started -> Cancel
      */
    if (!SoloPlayer[iClient].bCanSoloCommand || IsClientObserver(iClient) || bRoundStarted) {
        CPrintToChat(iClient, "%t", "Command_Solo_NotUseRightNow");
        return;
    }
    /**
     * If Client Team is not Red or Blue -> Cancel
     */
    if (iCurrentTeam == 1 || iCurrentTeam == 0) {
        CPrintToChat(iClient, "%t", "Command_Solo_OnlyRedBlueTeam");
        return;
    }
    /**
      * If Rest of the Team is in Solo Queue -> Cancel
      */
    if (IsRestOfTeamInSoloQueue(iCurrentTeam)) {
        CPrintToChat(iClient, "%t", "Command_Solo_RestOfTeamInSolo");
        return;
    }
    /**
     * If Client is alive, force suicide
     */
    if (IsPlayerAlive(iClient)) { ForcePlayerSuicide(iClient); }
    /**
     * Add Client to Solo Queue
     */
    if (iCurrentTeam == 2) PushArrayCell(hRedQueue, GetClientUserId(iClient));
    if (iCurrentTeam == 3) PushArrayCell(hBlueQueue, GetClientUserId(iClient));
    SoloPlayer[iClient].bSoloMode = true;
    SoloPlayer[iClient].bAnyTeam = false;
    SoloPlayer[iClient].iTeam = iCurrentTeam;
    SoloPlayer[iClient].bHasRespawned = false;
    CPrintToChat(iClient, "%t", "Command_Solo_Activated", iClient);
}

/**
 * All other Events
 */
public Action PlayerDeathEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    /**
     * If the Client is a Bot -> Cancel
     */
    if (IsFakeClient(iClient)) return Plugin_Continue;
    int iTeam = GetClientTeam(iClient);
    /**
     * If Client's Team Queue Size is 0 & NoPreferenceQueue is 0 -> Cancel
     */
    if (iTeam == 2 && GetArraySize(hRedQueue) == 0 && GetArraySize(hNoPreferenceQueue) == 0) return Plugin_Continue;
    if (iTeam == 3 && GetArraySize(hBlueQueue) == 0 && GetArraySize(hNoPreferenceQueue) == 0) return Plugin_Continue;

    /**
     * If Client Team is Red and PlayersAlive of Red are 1 -> Continue
     */
    if (iTeam == 2 && GetRedAlivePlayerCount() == 1) {
        if (!IsPlayerInAnyTeamQueue(iClient) && !IsPlayerInRedTeamQueue(iClient)) {
            CPrintToChatAll(">>> Player wasn't in a queue");
            /**
             * Client was not in the Red Queue or NoPref Queue
             */
            int iFirstClient = -1;
            /**
             * If Solo Queue from Red has players, take first from Red Queue
             */
            if (GetArraySize(hRedQueue) >= 1) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hRedQueue, 0));
            /**
             * If Solo Queue from Red is empty, take first from NoPref Queue
             */
            } else if (GetArraySize(hNoPreferenceQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, 0));
            /**
             * If No Queue Player was found -> Cancel
             */
            } else return Plugin_Continue;
            if (GetClientTeam(iFirstClient) != 2) {
                ChangeClientTeam(iFirstClient, 2);
            }
            /**
             * If Solo Queue Player was found and hasn't been respawned yet
             * -> Respawn First Player
             */
            if (iFirstClient != -1 && !SoloPlayer[iFirstClient].bHasRespawned ) {
                TF2_RespawnPlayer(iFirstClient);
                SoloPlayer[iFirstClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iFirstClient;
                SDKHook(iFirstClient, SDKHook_OnTakeDamage, OnTakeDamage);
                SoloPlayer[iFirstClient].bNoDamage = true;
                ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        } else {
            CPrintToChatAll("Player was in a queue");
            /**
             * Client was in Red Queue or NoPref Queue
             */
            int iNextIndex = -1;
            /**
             * Getting Next Client from Red Queue
             */
            iNextIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient)) + 1;
            CPrintToChatAll("NEXT INDEX: %i /// ARRAY SIZE RED: %i", iNextIndex, GetArraySize(hRedQueue));
            bool bNoPreferencePlayer = false;
            /**
             * If Next Array Index is bigger than Red Queue Size or equals 0
             * -> Search in NoPref Queue
             */
            if (iNextIndex > GetArraySize(hRedQueue) || iNextIndex == 0) {
                bNoPreferencePlayer = true;
                iNextIndex = FindValueInArray(hNoPreferenceQueue,  GetClientUserId(iClient)) + 1;
                /**
                 * If Next Array Index is bigger than NoPref Queue Size or equals 0 -> Cancel
                 */
                CPrintToChatAll("NEXT INDEX: %i /// ARRAY SIZE NOPREF: %i", iNextIndex, GetArraySize(hNoPreferenceQueue));
                if (iNextIndex > GetArraySize(hNoPreferenceQueue) || iNextIndex == 0) return Plugin_Continue;
            }
            
            int iNextClient = -1;
            /**
             * Get Next Client Index from Red Queue or NoPref Queue
             */
            if (bNoPreferencePlayer) {
                iNextClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, iNextIndex));
            } else {
                iNextClient = GetClientOfUserId(GetArrayCell(hRedQueue, iNextIndex));
            }
            /**
             * If Client is not in Team Red -> Change It
             */
            if (GetClientTeam(iNextClient) != 2) {
                ChangeClientTeam(iNextClient, 2);
            }
            /**
             * If Next Client was found and hasn't been respawned yet
             * -> Respawn Next player
             */
            if (!SoloPlayer[iNextClient].bHasRespawned && iNextClient != -1) {
                TF2_RespawnPlayer(iNextClient);
                SoloPlayer[iNextClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iNextClient;
                SDKHook(iNextClient, SDKHook_OnTakeDamage, OnTakeDamage);
                SoloPlayer[iNextClient].bNoDamage = true;
                ClientCommand(iNextClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        }
    }
    /**
     * If Client Team is Blue and PlayersAlive of Blue are 1 -> Continue
     */

    if (iTeam == 3 && GetBlueAlivePlayerCount() == 1) {
        if (!IsPlayerInAnyTeamQueue(iClient) && !IsPlayerInBlueTeamQueue(iClient)) {
            /**
             * Client was not in the Blue Queue or NoPref Queue
             */
            int iFirstClient = -1;
            /**
             * If Solo Queue from Blue has players, take first from Blue Queue
             */
            if (GetArraySize(hBlueQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hBlueQueue, 0));
            /**
             * If Solo Queue from Blue is empty, take first from NoPref Queue
             */
            } else if (GetArraySize(hNoPreferenceQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, 0));
            /**
             * If No Queue Player was found -> Cancel
             */
            } else return Plugin_Continue;
            if (GetClientTeam(iFirstClient) != 3) {
                ChangeClientTeam(iFirstClient, 3);
            }
            /**
             * If Solo Queue Player was found and hasn't been respawned yet
             * -> Respawn First Player
             */
            if (iFirstClient != -1 && !SoloPlayer[iFirstClient].bHasRespawned ) {
                TF2_RespawnPlayer(iFirstClient);
                SoloPlayer[iFirstClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iFirstClient;
                SDKHook(iFirstClient, SDKHook_OnTakeDamage, OnTakeDamage);
                SoloPlayer[iFirstClient].bNoDamage = true;
                ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        } else {
            /**
             * Client was in Red Queue or NoPref Queue
             */
            int iNextIndex = -1;
            /**
             * Getting Next Client from Blue Queue
             */
            iNextIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient)) + 1;
            bool bNoPreferencePlayer = false;
            /**
             * If Next Array Index is bigger than Blue Queue Size or equals 0
             * -> Search in NoPref Queue
             */
            if (iNextIndex > GetArraySize(hBlueQueue) || iNextIndex == 0) {
                bNoPreferencePlayer = true;
                iNextIndex = FindValueInArray(hNoPreferenceQueue,  GetClientUserId(iClient)) + 1;
                /**
                 * If Next Array Index is bigger than NoPref Queue Size or equals 0 -> Cancel
                 */
                if (iNextIndex > GetArraySize(hNoPreferenceQueue) || iNextIndex == 0) return Plugin_Continue;
            }
            
            int iNextClient = -1;
            /**
             * Get Next Client Index from Blue Queue or NoPref Queue
             */
            if (bNoPreferencePlayer) {
                iNextClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, iNextIndex));
            } else {
                iNextClient = GetClientOfUserId(GetArrayCell(hBlueQueue, iNextIndex));
            }
            if (GetClientTeam(iNextClient) != 3) {
                ChangeClientTeam(iNextClient, 3);
            }
            /**
             * If Next Client was found and hasn't been respawned yet
             * -> Respawn Next player
             */
            if (!SoloPlayer[iNextClient].bHasRespawned && iNextClient != -1) {
                TF2_RespawnPlayer(iNextClient);
                SoloPlayer[iNextClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iNextClient;
                SDKHook(iNextClient, SDKHook_OnTakeDamage, OnTakeDamage);
                SoloPlayer[iNextClient].bNoDamage = true;
                ClientCommand(iNextClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        }
    }


    /**
     * If Solo Round started, decrease death sound count
     */
    if (bRoundStarted) {
        /**
         * If Client Team is Red 
         */
        if (iTeam == 2) {
            for (int i = 0; i < GetArraySize(hRedQueue); i++) {
                int iQueuedClient = GetClientOfUserId(GetArrayCell(hRedQueue, i));
                if (IsClientConnected(iQueuedClient) && SoloPlayer[iQueuedClient].iDeaths > 0 && SoloPlayer[iQueuedClient].iDeaths <= 5) {
                    ClientCommand(iQueuedClient, "playgamesound \"vo\\announcer_begins_%dsec.mp3\"", SoloPlayer[iQueuedClient].iDeaths);
                    SoloPlayer[iQueuedClient].iDeaths--;
                }
            }
        }
        if (iTeam == 3) {
            for (int i = 0; i < GetArraySize(hBlueQueue); i++) {
                int iQueuedClient = GetClientOfUserId(GetArrayCell(hBlueQueue, i));
                if (IsClientConnected(iQueuedClient) && SoloPlayer[iQueuedClient].iDeaths > 0 && SoloPlayer[iQueuedClient].iDeaths <= 5) {
                    SoloPlayer[iQueuedClient].iDeaths--;
                    ClientCommand(iQueuedClient, "playgamesound \"vo\\announcer_begins_%dsec.mp3\"", SoloPlayer[iQueuedClient].iDeaths);
                }
            }
        }
    }
    return Plugin_Continue;
}
public Action RoundEndEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    /**
     * Reset Round Started / Player Respawned / Player Command Cooldown / Player Damage State & Disable Solo Command 
     */
    bRoundStarted = false;
    for (int i = 1; i <= MaxClients; i++) {
        SoloPlayer[i].bHasRespawned = false;
        SoloPlayer[i].bCanSoloCommand = false;
        SoloPlayer[i].iLastUsed = 0;
        SoloPlayer[i].bNoDamage = false;
    }
    return Plugin_Continue;
}
public Action RoundStartEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    /**
     * Create Round Start Timer
     */
    CreateTimer(0.3, RoundStartTimer);
    return Plugin_Continue;
}
public Action RoundSetupEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    /**
     * Reset Basic Settings (Just to be sure)
     */
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i)) {
            SoloPlayer[i].bHasRespawned = false;
            SoloPlayer[i].bCanSoloCommand = true;
            SoloPlayer[i].bNoDamage = false;
            SoloPlayer[i].iLastUsed = 0;
            SoloPlayer[i].iDeaths = 0;
        }
    }
    return Plugin_Continue;
}
public Action PlayerTeamEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    /**
     * If Client is Connected and is a Bot -> Cancel
     */
    if (IsClientConnected(iClient) && IsFakeClient(iClient)) return Plugin_Continue;

    int iTeam = GetEventInt(hEvent, "team");
    int iOldTeam = GetEventInt(hEvent, "oldteam");
    SoloPlayer[iClient].iTeam = iTeam;
    /**
     * If Client has Solo Mode activated
     */
    if (SoloPlayer[iClient].bSoloMode) {
        /**
         * If new Team is Spectator/Unassigned -> Remove Client from any Queues 
         */
        if (iTeam == 0 || iTeam == 1) {
            CPrintToChat(iClient, "%t", "TeamChange_ToSpectator");
            if (IsPlayerInRedTeamQueue(iClient)) {
                int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            }
            if (IsPlayerInBlueTeamQueue(iClient)) {
                int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            }
            if (IsPlayerInAnyTeamQueue(iClient)) {
                int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hNoPreferenceQueue, iIndex);
            }
        }
        /**
         * If new Team is Red, Client is not in NoPref Queue, Client is in Blue Queue and old Team was Blue
         * -> Change Solo Queue from Blue to Red
         */
        if (iTeam == 2 && iOldTeam == 3 && !IsPlayerInAnyTeamQueue(iClient) && IsPlayerInBlueTeamQueue(iClient)) {
            int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            PushArrayCell(hRedQueue, GetClientUserId(iClient));
            CPrintToChat(iClient, "%t", "TeamChange_BlueToRed");
        }
        /**
         * If new Team is Blue, Client is not in NOPREF Queue, Client is in Red Queue and old Team was Red
         * -> Change Solo Queue from Red to Blue
         */
        if (iTeam == 3 && iOldTeam == 2 && !IsPlayerInAnyTeamQueue(iClient) && IsPlayerInRedTeamQueue(iClient)) {
            int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            PushArrayCell(hBlueQueue, GetClientUserId(iClient));
            CPrintToChat(iClient, "%t", "TeamChange_RedToBlue");
        }
    }
    return Plugin_Continue;
}
public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &damagetype) {
    /**
     * If Player is Alive, Solo Mode is Activated and NoDamage is enabled -> Continue
     */
    if (IsPlayerAlive(iVictim) && SoloPlayer[iVictim].bSoloMode && SoloPlayer[iVictim].bNoDamage) {
        /**
         * Change Damage to 0, Disable NoDamge, Unhook OnTakeDamage
         */
        fDamage = 0.0;
        SDKUnhook(iVictim, SDKHook_OnTakeDamage, OnTakeDamage);
        SoloPlayer[iVictim].bNoDamage = false;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}
public void OnGameFrame() {
    /**
     * If Last Respawned Client is not 0 or -1, Client is Connected, Client is Alive, NoDamage is enabled and GameTickCount bigger than LastRespawnTime
     * -> Unhook OnTakeDamage / Disable NoDamage
     */
    if (iLastRespawnedClient != 0 && iLastRespawnedClient != -1 && IsClientConnected(iLastRespawnedClient) && IsPlayerAlive(iLastRespawnedClient) && SoloPlayer[iLastRespawnedClient].bNoDamage && GetGameTickCount() > iLastRespawnTime) {
        SoloPlayer[iLastRespawnedClient].bNoDamage = false;
        SDKUnhook(iLastRespawnedClient, SDKHook_OnTakeDamage, OnTakeDamage);
    }
    /**
     * If Map hasn't changed, Team Red and Team Blue ClientCountWithBots equals 1 -> Continue
     */
    if (!bMapChanged && GetTeamClientCountWithBots(2) <= 1 && GetTeamClientCountWithBots(3) <= 1) {
        /**
         * If a Queue Size is not equal to 0, Clear Queue
         * Reset CanSoloCommand and SoloMode for every player
         */
        if (GetArraySize(hRedQueue) != 0) ClearArray(hRedQueue);
        if (GetArraySize(hBlueQueue) != 0) ClearArray(hBlueQueue);
        if (GetArraySize(hNoPreferenceQueue) != 0) ClearArray(hNoPreferenceQueue);
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientConnected(i) && SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (IsClientConnected(i) && SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
    }
    /**
     * If Map hasn't changed, Team Red ClientCountWithBots is bigger than 0 and equals the Solo Queue from Red
     * -> Reset CanSoloCommand and SoloMode for every Red Player, Clear Red Queue, Print Message
     */
    if (!bMapChanged && GetTeamClientCountWithBots(2) > 0 && GetTeamClientCountWithBots(2) == GetArraySize(hRedQueue)) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientConnected(i) && GetClientTeam(i) == 2 && SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (IsClientConnected(i) && GetClientTeam(i) == 2 && SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
        ClearArray(hRedQueue);
        CPrintToChatAll("%t", "Red_SoloQueueCleared");
    }
    /**
     * If Map hasn't changed, Team Blue ClientCountWithBots is bigger than 0 and equals the Solo Queue from Blue
     */
    if (!bMapChanged && GetTeamClientCountWithBots(3) > 0 && GetTeamClientCountWithBots(3) == GetArraySize(hBlueQueue)) {
        for (int i = 1; i < MaxClients; i++) {
            if (IsClientConnected(i) && SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (IsClientConnected(i) && SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
        ClearArray(hBlueQueue);
        CPrintToChatAll("%t", "Blue_SoloQueueCleared");
    }

}
/**
 * Some Dynamic Values
 */
stock int GetRedAlivePlayerCount() {
	int iAlive = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2) {
			iAlive++;
		}
	}
	return iAlive;
}
stock int GetBlueAlivePlayerCount() {
	int iAlive = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3) {
			iAlive++;
		}
	}
	return iAlive;
}
stock int GetTeamClientCountWithBots(int iTeam) {
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == iTeam) {
			iCount++;
		}
	}
	return iCount;
}
stock bool IsRestOfTeamInSoloQueue(int iCurrentTeam) {
    int iCurrentTeamCount = TeamClientCount(iCurrentTeam);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && GetClientTeam(i) == iCurrentTeam) {
            if (IsPlayerInAnyTeamQueue(i) || IsPlayerInRedTeamQueue(i) || IsPlayerInBlueTeamQueue(i)) { iCurrentTeamCount--; }
        }
    }
    return iCurrentTeamCount <= 1;
}
stock int TeamClientCount(int iTeam) {
    int iValue = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && GetClientTeam(i) == iTeam) { iValue++; }
    }
    return iValue;
}
stock bool IsPlayerInAnyTeamQueue(int iClient) {
    int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
    return iIndex != -1;
}
stock bool IsPlayerInBlueTeamQueue(int iClient) {
    int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
    return iIndex != -1;
}
stock bool IsPlayerInRedTeamQueue(int iClient) {
    int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
    return iIndex != -1;
}
/**
 * Basic Timers
 */
public Action RoundStartTimer(Handle hTimer) {
    /**
     * Disable Solo Command
     */
    bRoundStarted = true;
    /**
     * If Team Client Count from Red and Blue are 1 -> Cancel
     */
    if (GetTeamClientCount(2) <= 1 && GetTeamClientCount(3) <= 1) return Plugin_Continue;
    bool bHasNames = false;
    char sNames[1024];
    /**
     * Kill Every Player that has enabled Solo Mode
     */
    for (int i = 1; i <= MaxClients; i++) {
        char sName[MAX_NAME_LENGTH];
        if (IsClientInGame(i) && SoloPlayer[i].bSoloMode) {
            ForcePlayerSuicide(i);
            SDKHooks_TakeDamage(i, i, i, 450.0);
            CPrintToChat(i, "%t", "Command_Solo_Slain");
            CPrintToChat(i, "%t", "Command_Solo_Slain2");
            GetClientName(i, sName, sizeof(sName));
            Format(sNames, sizeof(sNames), "%s %s,", sNames, sName);
            bHasNames = true;
        }
    }
    /**
     * Print Message with all Players that have enabled Solo Mode
     */
    if (bHasNames)
        CPrintToChatAll("%t", "RoundStart_SoloPlayers", sNames);
    /**
     * (idk) For every player that has activated Solo Mode, set deaths count to the Team Alive Count + Index of Solo Queue - 1
     * -> Used for Respawn Sound
     */
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && SoloPlayer[i].bSoloMode) {
            if (GetClientTeam(i) == 2)
                if(IsPlayerInRedTeamQueue(i)) SoloPlayer[i].iDeaths = GetRedAlivePlayerCount() + (FindValueInArray(hRedQueue, GetClientUserId(i)) - 1);
                else SoloPlayer[i].iDeaths = GetRedAlivePlayerCount() + (FindValueInArray(hNoPreferenceQueue, GetClientUserId(i)) - 1);
            if (GetClientTeam(i) == 3) {
                if(IsPlayerInBlueTeamQueue(i)) SoloPlayer[i].iDeaths = GetBlueAlivePlayerCount() + (FindValueInArray(hBlueQueue, GetClientUserId(i)) - 1);
                else SoloPlayer[i].iDeaths = GetBlueAlivePlayerCount() + (FindValueInArray(hNoPreferenceQueue, GetClientUserId(i)) - 1);
            }
        }
    }
    return Plugin_Continue;
}
public Action MapStartTimer(Handle hTimer) {
    /**
     * Resets Map Changed State
     */
    bMapChanged = false;
    return Plugin_Handled;
}
public Action RemoveFromQueueTimer(Handle hTimer, int iClient) {
    /**
     * Removes Client from Solo Queue
     * -> Used for Removing first Client from Queue after last Alive Client disconnected
     */
    if (IsPlayerInAnyTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hNoPreferenceQueue, iIndex);
    } else if (IsPlayerInBlueTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
    } else if (IsPlayerInRedTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
    }
    return Plugin_Continue;
}
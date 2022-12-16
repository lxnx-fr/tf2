#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <multicolors>
#include <tf2>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#define PLUGIN_VERSION 		"1.2"
#define PLUGIN_NAME 		"sakaSOLO"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Take on the other team solely (Intended for dodgeball)."
#define PLUGIN_URL 			"https://tf2.l03.dev/"

#define COMMAND_COOLDOWN    150

Handle hRedQueue = INVALID_HANDLE;
Handle hBlueQueue = INVALID_HANDLE;
Handle hNoPreferenceQueue = INVALID_HANDLE;

bool bMapChanged;
bool bSoloRoundStart;
int iLastRespawnTime;
int iLastRespawnedClient;

enum struct SoloInfo {
    bool bSoloMode;
    bool bAnyTeam;
    bool bHasRespawned;
    int iTeam;
    bool bCanSoloCommand;
    int iDeaths;
    bool bNoDamage;
    int iLastUsed;
}
SoloInfo SoloPlayer[MAXPLAYERS +1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart() {
    PrintToServer("[sakaSOLO] Enabling Plugin (Version %s)", PLUGIN_VERSION);
    hRedQueue = CreateArray();
    hBlueQueue = CreateArray();
    hNoPreferenceQueue = CreateArray();
    HookEvent("player_death", PlayerDeathEvent, EventHookMode_Pre);
    HookEvent("arena_round_start", RoundStartEvent, EventHookMode_Post);
    HookEvent("player_team", PlayerTeamEvent);
    HookEvent("arena_win_panel", RoundEndEvent);
}

public void OnPluginEnd() {
    PrintToServer("[sakaSOLO] Disabling Plugin");
}


/**
 * Beispiel: 
 * 8 Spieler
 * 3 Team Rot
 * 4 Team Blau
 * 1 Zuschauer
 * 
 * Wenn A aus Blau /solo macht 
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
                case 0: {
                    AddToEnemyTeamQueue(iClient);
                }
                case 1: {
                    AddToAnyTeamQueue(iClient);
                }
            }
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}
stock bool IsRestOfTeamInSoloQueue(int iCurrentTeam) {
    int iCurrentTeamCount = TeamClientCount(iCurrentTeam);
    for (int i = 0; i <= MaxClients; i++) {
        if (GetClientTeam(i) == iCurrentTeam) {
            if (IsPlayerInAnyTeamQueue(i) || IsPlayerInRedTeamQueue(i) || IsPlayerInBlueTeamQueue(i)) {
                iCurrentTeamCount--;
            }
        }
    }
    return iCurrentTeamCount <= 1;
}
stock int TeamClientCount(int iTeam) {
    int iValue = 0;
    for (int i = 0; i <= MaxClients; i++) {
        if (GetClientTeam(i) == iTeam) {
            iValue++;
        }
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
public void AddToAnyTeamQueue(int iClient) {
    int iCurrentTeam = GetClientTeam(iClient);
    SoloPlayer[iClient].bSoloMode = true;
    SoloPlayer[iClient].bAnyTeam = false;
    SoloPlayer[iClient].iTeam = iCurrentTeam;
}

public void AddToEnemyTeamQueue(int iClient) {
    
    int iCurrentTeam = GetClientTeam(iClient);
    /**
     * If Client Team is not RED OR BLUE -> Cancel
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
    if (IsPlayerAlive(iClient)) {
        ForcePlayerSuicide(iClient);
        CPrintToChat(iClient, "%t", "Command_Solo_Slain");
        CPrintToChat(iClient, "%t", "Command_Solo_Slain2");
    }
    if (iCurrentTeam == 2) PushArrayCell(hRedQueue, GetClientUserId(iClient));
    if (iCurrentTeam == 3) PushArrayCell(hBlueQueue, GetClientUserId(iClient));
    SoloPlayer[iClient].bSoloMode = true;
    SoloPlayer[iClient].bAnyTeam = false;
    SoloPlayer[iClient].iTeam = iCurrentTeam;
    CPrintToChatAll("%t", "Command_Solo_Activated", iClient);
}

public Action SoloCommand(int iClient, int iArgs) {
    /**
     * If Client is not InGame -> Cancel
     */
    if (!IsClientInGame(iClient))
        return Plugin_Handled;
    int iTeam = GetClientTeam(iClient);
    /**
     * If Client has Command Cooldown -> Cancel
     */
    int iCurrentTime = GetTime();
    if ((iCurrentTime - SoloPlayer[iClient].iLastUsed) < COMMAND_COOLDOWN) {
        CPrintToChat(iClient, "%t", "Command_Solo_Cooldown", 150 - (iCurrentTime - SoloPlayer[iClient].iLastUsed));
        return Plugin_Handled;
    }
    SoloPlayer[iClient].iLastUsed = GetTime();
    /**
     * If Client Team is not RED OR BLUE -> Cancel
     */
    if (iTeam == 1 || iTeam == 0) {
        CPrintToChat(iClient, "%t", "Command_Solo_OnlyRedBlueTeam");
        return Plugin_Handled;
    }
    /**
     * If Client is not in Solo Mode -> Open Solo Menu
     */
    if (!SoloPlayer[iClient].bSoloMode) {
        /**
         * If Client can't execute Solo Command or is Observer -> Cancel
         */
        if (!SoloPlayer[iClient].bCanSoloCommand || IsClientObserver(iClient)) {
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
         * If Client has ANY-TEAM Solo Mode: remove Client from NoPreference Queue
         * Else: remove Client from RED/BLUE Team Queue
         * And: set SoloMode, anyteam to false
         */
        if (SoloPlayer[iClient].bAnyTeam) {
            int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hNoPreferenceQueue, iIndex);
        } else {
            if (SoloPlayer[iClient].iTeam == 2) {
                int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            } else if (SoloPlayer[iClient].iTeam == 3) {
                int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            } else {
                PrintToServer("[sakaSOLO] Team not valid %i for %N", SoloPlayer[iClient].iTeam, iClient);
            }
        }
        SoloPlayer[iClient].iTeam = 0;
        SoloPlayer[iClient].bSoloMode = false;
        SoloPlayer[iClient].bAnyTeam = false;
        SoloPlayer[iClient].bCanSoloCommand = true;
        SoloPlayer[iClient].bHasRespawned = false;
        SoloPlayer[iClient].iDeaths = 0;
        CPrintToChatAll("%t", "Command_Solo_Deactivated", iClient);
    }
    return Plugin_Handled;
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
    int iTeam = GetClientTeam(iClient);
    /**
     * If Client is in Team RED/BLUE/NOPREFERENCE Queue, remove him from SOLO queue
     */
    if (IsPlayerInAnyTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hNoPreferenceQueue, iIndex);
    }
    if (IsPlayerInBlueTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
    }
    if (IsPlayerInRedTeamQueue(iClient)) {
        int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
    }
}

public void OnMapEnd() {
    bMapChanged = true;
}

public void OnMapStart() {
    ClearArray(hRedQueue);
    ClearArray(hBlueQueue);
    ClearArray(hNoPreferenceQueue);
    CreateTimer(10.0, MapStartTimer);
    bSoloRoundStart = false;
}

public Action MapStartTimer(Handle hTimer) {
    bMapChanged = false;
    return Plugin_Handled;
}
public Action PlayerDeathEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    /**
     * If the Client is a Bot -> Cancel
     */
    if (IsFakeClient(iClient)) return Plugin_Handled;

    int iTeam = GetClientTeam(iClient);

    /**
     * If Client's Team Queue Size is 0 & NoPreferenceQueue is 0 -> Cancel
     */
    if (iTeam == 2 && GetArraySize(hRedQueue) == 0 && GetArraySize(hNoPreferenceQueue) == 0) return Plugin_Handled;
    if (iTeam == 3 && GetArraySize(hBlueQueue) == 0 && GetArraySize(hNoPreferenceQueue) == 0) return Plugin_Handled;

    /**
     * If Client Team is RED and PlayersAlive of RED are 1 -> Continue
     */
    if (iTeam == 2 && GetRedAlivePlayerCount() == 1) {
        
        // If the client who died was not in RED QUEUE and not in NOPREFERENCE QUEUE -> Continue
        if (FindValueInArray(hRedQueue, GetClientUserId(iClient)) == -1 && FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient))) {
            int iFirstClient = -1;
            /**
             * If Solo Queue from RED Team has players, take next from RED Queue
             */
            if (GetArraySize(hRedQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hRedQueue, 0));
            /**
             * If Solo Queue from RED Team is empty, take next from NoPreference Queue
             */
            } else if (GetArraySize(hNoPreferenceQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, 0));
            /**
             * If No Queue Players exist print error (is normally checked before?)
             */
            } else {
                PrintToServer("[sakaSOLO] Failed -> no queue players");
            }
            /**
             * If Solo Queue Player exists and hasn't been respawned yet
             * -> Respawn next player
             */
            if (iFirstClient != -1 && !SoloPlayer[iFirstClient].bHasRespawned ) {
                TF2_RespawnPlayer(iFirstClient);
                SoloPlayer[iFirstClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iFirstClient;
                ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        } else {
            /**
             * If the last client who died was in a queue 
             */
            int iNextIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient)) + 1;
            bool bNoPreferencePlayer = false;
            /**
             * If no next client from red queue is available or next index is -1
             */
            if (iNextIndex >= GetArraySize(hRedQueue) || iNextIndex == -1) {
                /**
                 * If also no next client from no preference queue is available or next index is -1, cancel
                 */
                bNoPreferencePlayer = true;
                iNextIndex = FindValueInArray(hNoPreferenceQueue,  GetClientUserId(iClient)) + 1;
                if (iNextIndex >= GetArraySize(hNoPreferenceQueue) || iNextIndex == -1) {
                    PrintToServer("[sakaSOLO] No next player from red queue or nopreference queue was found for team red ");
                    return Plugin_Handled;
                } 
            }
            int iNextClient = -1;
            /**
             * Get next client index from RED Queue or NoPreference Queue
             */
            if (bNoPreferencePlayer) {
                iNextClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, iNextIndex));
            } else {
                iNextClient = GetClientOfUserId(GetArrayCell(hRedQueue, iNextIndex));
            }
            /**
             * If next client hasn't been respawned yet & client index is not -1
             * -> Respawn next player
             */
            if (!SoloPlayer[iNextClient].bHasRespawned && iNextClient != -1) {
                TF2_RespawnPlayer(iClient);
                SoloPlayer[iNextClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iNextClient;
                ClientCommand(iNextClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        }
    }
    /**
     * If Client Team is BLUE and PlayersAlive of BLUE are 1 -> Continue
     */
    if (iTeam == 3 && GetBlueAlivePlayerCount() == 1) {
        
        // If the client who died was not in BLUE QUEUE and not in NOPREFERENCE QUEUE -> Continue
        if (FindValueInArray(hBlueQueue, GetClientUserId(iClient)) == -1 && FindValueInArray(hNoPreferenceQueue, GetClientUserId(iClient))) {
            int iFirstClient = -1;
            /**
             * If Solo Queue from BLUE Team has players, take next from BLUE Queue
             */
            if (GetArraySize(hBlueQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hBlueQueue, 0));
            /**
             * If Solo Queue from BLUE Team is empty, take next from NoPreference Queue
             */
            } else if (GetArraySize(hNoPreferenceQueue) > 0) {
                iFirstClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, 0));
            /**
             * If No Queue Players exist print error (is normally checked before?)
             */
            } else {
                PrintToServer("[sakaSOLO] Failed -> no queue players");
            }
            /**
             * If Solo Queue Player exists and hasn't been respawned yet
             * -> Respawn next player
             */
            if (iFirstClient != -1 && !SoloPlayer[iFirstClient].bHasRespawned ) {
                TF2_RespawnPlayer(iFirstClient);
                SoloPlayer[iFirstClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iFirstClient;
                ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        } else {
            /**
             * If the last client who died was in a queue 
             */
            int iNextIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient)) + 1;
            bool bNoPreferencePlayer = false;
            /**
             * If no next client from blue queue is available or next index is -1
             */
            if (iNextIndex >= GetArraySize(hBlueQueue) || iNextIndex == -1) {
                /**
                 * If also no next client from no preference queue is available or next index is -1, cancel
                 */
                bNoPreferencePlayer = true;
                iNextIndex = FindValueInArray(hNoPreferenceQueue,  GetClientUserId(iClient)) + 1;
                if (iNextIndex >= GetArraySize(hNoPreferenceQueue) || iNextIndex == -1) {
                    PrintToServer("[sakaSOLO] No next player from blue queue or nopreference queue was found for team blue ");
                    return Plugin_Handled;
                } 
            }
            int iNextClient = -1;
            /**
             * Get next client index from BLUE Queue or NoPreference Queue
             */
            if (bNoPreferencePlayer) {
                iNextClient = GetClientOfUserId(GetArrayCell(hNoPreferenceQueue, iNextIndex));
            } else {
                iNextClient = GetClientOfUserId(GetArrayCell(hBlueQueue, iNextIndex));
            }
            /**
             * If next client hasn't been respawned yet & client index is not -1
             * -> Respawn next player
             */
            if (!SoloPlayer[iNextClient].bHasRespawned && iNextClient != -1) {
                TF2_RespawnPlayer(iClient);
                SoloPlayer[iNextClient].bHasRespawned = true;
                iLastRespawnTime = GetGameTickCount();
                iLastRespawnedClient = iNextClient;
                ClientCommand(iNextClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        }
    }
    /**
     * If Solo Round started
     */
    if (bSoloRoundStart) {
        if (iTeam == 2) {
            for (int i = 0; i < GetArraySize(hRedQueue); i++) {
                int iQueuedClient = GetClientOfUserId(GetArrayCell(hRedQueue, i));
                if (SoloPlayer[iQueuedClient].iDeaths > 0 && SoloPlayer[iQueuedClient].iDeaths <= 5) {
                    ClientCommand(iQueuedClient, "playgamesound \"vo\\announcer_begins_%dsec.mp3\"", SoloPlayer[iQueuedClient].iDeaths);
                    SoloPlayer[iQueuedClient].iDeaths--;
                }
            }
        }
        if (iTeam == 3) {
            for (int i = 0; i < GetArraySize(hBlueQueue); i++) {
                int iQueuedClient = GetClientOfUserId(GetArrayCell(hBlueQueue, i));
                if (SoloPlayer[iQueuedClient].iDeaths > 0 && SoloPlayer[iQueuedClient].iDeaths <= 5) {
                    SoloPlayer[iQueuedClient].iDeaths--;
                    ClientCommand(iQueuedClient, "playgamesound \"vo\\announcer_begins_%dsec.mp3\"", SoloPlayer[iQueuedClient].iDeaths);
                }
            }
        }
    }
    return Plugin_Handled;
}

public Action RoundEndEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    bSoloRoundStart = false;
    for (int i = 1; i <= MaxClients; i++) {
        SoloPlayer[i].bCanSoloCommand = false;
        SoloPlayer[i].bHasRespawned = false;
    }
    return Plugin_Handled;
}

public Action RoundStartEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    CreateTimer(0.3, RoundStartTimer);
    return Plugin_Handled;
}

public Action RoundStartTimer(Handle hTimer) {
    if (GetTeamClientCount(2) <= 1 && GetTeamClientCount(3) <= 1) return Plugin_Handled;

    bool bHasNames = false;
    char sNames[1024];
    for (int i = 1; i < MaxClients; i++) {
        SoloPlayer[i].bCanSoloCommand = true;
        char sName[MAX_NAME_LENGTH];
        if (SoloPlayer[i].bSoloMode && IsClientInGame(i)) {
            ForcePlayerSuicide(i);
            CPrintToChat(i, "%t", "Command_Solo_Slain");
            CPrintToChat(i, "%t", "Command_Solo_Slain2");
            GetClientName(i, sName, sizeof(sName));
            Format(sNames, sizeof(sNames), "%s %s,", sNames, sName);
            bHasNames = true;
        }
    }
    if (bHasNames)
        CPrintToChatAll("%t", "RoundStart_SoloPlayers", sNames);
    bSoloRoundStart = true;
    for (int i = 1; i < MaxClients; i++) {
        if (SoloPlayer[i].bSoloMode) {
            SoloPlayer[i].bCanSoloCommand = false;
            if (GetClientTeam(i) == 2)
                if(IsPlayerInRedTeamQueue(i))
                    SoloPlayer[i].iDeaths = GetRedAlivePlayerCount() + (FindValueInArray(hRedQueue, GetClientUserId(i)) - 1);
                else
                    SoloPlayer[i].iDeaths = GetRedAlivePlayerCount() + (FindValueInArray(hNoPreferenceQueue, GetClientUserId(i)) - 1);
            if (GetClientTeam(i) == 3)
                if(IsPlayerInBlueTeamQueue(i))
                    SoloPlayer[i].iDeaths = GetBlueAlivePlayerCount() + (FindValueInArray(hBlueQueue, GetClientUserId(i)) - 1);
                else
                    SoloPlayer[i].iDeaths = GetBlueAlivePlayerCount() + (FindValueInArray(hNoPreferenceQueue, GetClientUserId(i)) - 1);

        }
    }
    return Plugin_Handled;
}
public Action RoundSetupEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    bSoloRoundStart = true;
    for (int i = 1; i <= MaxClients; i++) {
        SoloPlayer[i].bCanSoloCommand = true;
        SoloPlayer[i].bHasRespawned = false;
    }
    return Plugin_Handled;
}
public Action PlayerTeamEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    /**
     * If Client is Connected and is a Bot -> Cancel
     */
    if (IsClientConnected(iClient) && IsFakeClient(iClient)) return Plugin_Handled;
    /**
     * If Client has Solo Mode activated
     */
    if (SoloPlayer[iClient].bSoloMode) {
        int iTeam = GetEventInt(hEvent, "team");
        int iOldTeam = GetEventInt(hEvent, "oldteam");
        /**
         * If new team is spectator and client is not in NOPREFERENCE Queue
         */
        if (iTeam == 0 && !IsPlayerInAnyTeamQueue(iClient)) {
            if (iOldTeam == 2) {
                int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            }
            if (iOldTeam == 3) {
                    int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
                    if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            }
        }
        /**
         * If new team is RED and client is not in NOPREFERENCE QUEUE and old team was BLUE
         */
        if (iTeam == 2 && iOldTeam == 3 && !IsPlayerInAnyTeamQueue(iClient)) {
            int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
            if (iIndex != -1) {
                RemoveFromArray(hBlueQueue, iIndex);
                PushArrayCell(hRedQueue, GetClientUserId(iClient));
            }
        }
        /**
         * If new team is BLUE and client is not in NOPREFERENCE QUEUE and old team was RED
         */
        if (iTeam == 3 && iOldTeam == 2 && !IsPlayerInAnyTeamQueue(iClient)) {
            int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
            if (iIndex != -1) { 
                RemoveFromArray(hRedQueue, iIndex);
                PushArrayCell(hBlueQueue, GetClientUserId(iClient));
            }
        }
    }
    return Plugin_Handled;
}

public Action OnTakeDamage(int iVictim, int &attacker, int &iInflictor, float &fDamage, int &damagetype) {
  if (IsPlayerAlive(iVictim) && SoloPlayer[iVictim]) {
    fDamage = 0.0;
  }
  SDKUnhook(iVictim, SDKHook_OnTakeDamage, OnTakeDamage);
  SoloPlayer[iVictim].bNoDamage = true;
  return Plugin_Changed;
}

public void OnGameFrame() {
    if (iLastRespawnedClient != 0 && IsClientConnected(iLastRespawnedClient) && IsPlayerAlive(iLastRespawnedClient) && SoloPlayer[iLastRespawnedClient].bNoDamage &&GetGameTickCount() > iLastRespawnTime) {
        SDKUnhook(iLastRespawnedClient, SDKHook_OnTakeDamage, OnTakeDamage);
    }

    if (!bMapChanged && GetTeamClientCountWithBots(2) <= 1 && GetTeamClientCountWithBots(3) <= 1) {
        if (GetArraySize(hRedQueue) != 0) ClearArray(hRedQueue);
        if (GetArraySize(hBlueQueue) != 0) ClearArray(hBlueQueue);
        if (GetArraySize(hNoPreferenceQueue) != 0) ClearArray(hNoPreferenceQueue);
        for (int i = 1; i < MaxClients; i++) {
            if (SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
    }
    if (!bMapChanged && GetTeamClientCountWithBots(2) > 0 && GetTeamClientCountWithBots(2) == GetArraySize(hRedQueue)) {
        for (int i = 1; i < MaxClients; i++) {
            if (SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
        ClearArray(hRedQueue);
        CPrintToChatAll("%t", "Red_SoloQueueCleared");
    }
    if (!bMapChanged && GetTeamClientCountWithBots(3) > 0 && GetTeamClientCountWithBots(3) == GetArraySize(hBlueQueue)) {
        for (int i = 1; i < MaxClients; i++) {
            if (SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
        ClearArray(hBlueQueue);
        CPrintToChatAll("%t", "Blue_SoloQueueCleared");
    }
}

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
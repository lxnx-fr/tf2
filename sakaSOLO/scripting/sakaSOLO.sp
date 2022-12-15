#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <multicolors>
#include <tf2>
#include <sdktools>

#define PLUGIN_VERSION 		"1.2"
#define PLUGIN_NAME 		"sakaSOLO"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Take on the other team solely (Intended for dodgeball)."
#define PLUGIN_URL 			"https://tf2.l03.dev/"

Handle hRedQueue = INVALID_HANDLE;
Handle hBlueQueue = INVALID_HANDLE;
Handle hNoPreferenceQueue = INVALID_HANDLE;

bool bMapChanged;
bool bSoloRoundStart;
enum struct SoloInfo {
    bool bSoloMode;
    bool bAnyTeam;
    int iTeam;
    bool bCanSoloCommand;
    int iDeaths;
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
    menu.AddItem("0", "Against Any Enemy Team");
    menu.AddItem("1", "Against current Enemy Team");
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}
public int SoloMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            switch (iItem) {
                case 0: {
                    AddToAnyTeamQueue(iClient);
                }
                case 1: {
                    AddToEnemyTeamQueue(iClient);
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
     * If Client is in TEAM RED/BLUE -> continue
     */
    if (iCurrentTeam == 1 || iCurrentTeam == 0) {
        CPrintToChat(iClient, "%t", "Command_Solo_OnlyRedBlueTeam");
        return;
    }
    /**
     * If Client can use Solo CMD & is not an Observer -> continue
     */
    if (!SoloPlayer[iClient].bCanSoloCommand || IsClientObserver(iClient)) {
        CPrintToChat(iClient, "%t", "Command_Solo_UseNotRightNow");
        return;
    }
    if (IsRestOfTeamInSoloQueue(iCurrentTeam)) {
        CPrintToChat(iClient, "%t", "Command_Solo_RestOfTeamAlreadySolo");
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
}

public Action SoloCommand(int iClient, int iArgs) {
    /**
     * If Client is not InGame -> cancel
     */
    if (!IsClientInGame(iClient))
        return Plugin_Handled;
    int iTeam = GetClientTeam(iClient);
    /**
     * If Client Team is not RED OR BLUE -> cancel
     */
    if (iTeam == 1 || iTeam == 0) {
        CPrintToChat(iClient, "%t", "Command_Solo_OnlyRedBlueTeam");
        return Plugin_Handled;
    }
    /**
     * If Client is not in Solo Mode -> Open Solo Menu
     */
    if (!SoloPlayer[iClient].bSoloMode) {
        DrawSoloMenu(iClient);
    } else {
        /**
         * If Client has ANY-TEAM Solo Mode: remove it from NoPreferenceQueue
         * Else: remove Client from RED/BLUE Team Queue
         * And: set SoloMode, cansolo to false
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
        CPrintToChatAll("%t", "Command_Solo_Deactivated", iClient);
    }


    /**
     * If Client Solomode is disabled
     */
    if (!SoloPlayer[iClient].bSoloMode) {
        /**
         * If Client can't solo or is an observer -> cancel
         */
        if (!SoloPlayer[iClient].bCanSoloCommand || IsClientObserver(iClient)) {
            CPrintToChat(iClient, "%t", "Command_Solo_UseNotRightNow");
            return Plugin_Handled;
        }
        /**
         * If Client Team is RED/BLUE and Team RED/BLUE PLAYER COUNT 
         * equals SOLO queue -> cancel
         */
        if (iTeam == 2 && (GetTeamClientCount(2) - 1) == GetArraySize(hRedQueue)) {
            CPrintToChat(iClient, "%t", "Command_Solo_RestOfTeamAlreadySolo");
            return Plugin_Handled;
        }
        if (iTeam == 3 && (GetTeamClientCount(3) - 1) == GetArraySize(hBlueQueue)) {
            CPrintToChat(iClient, "%t", "Command_Solo_RestOfTeamAlreadySolo");
            return Plugin_Handled;
        }
        /**
         * If Client is alive -> Suicide & Print Message
         */
        if (IsPlayerAlive(iClient)) {
            ForcePlayerSuicide(iClient);
            CPrintToChat(iClient, "%t", "Command_Solo_Slain");
            CPrintToChat(iClient, "%t", "Command_Solo_Slain2");
        }
        /**
         * If Team is RED/BLUE, add Client to RED/BLUE Solo Queue
         */
        if (iTeam == 2) PushArrayCell(hRedQueue, GetClientUserId(iClient));
        if (iTeam == 3) PushArrayCell(hBlueQueue, GetClientUserId(iClient));
        /**
         * Enable Solo Mode for Client
         * Print Solomode Activated to all Clients
         */
        SoloPlayer[iClient].bSoloMode = true;
        CPrintToChatAll("%t", "Command_Solo_Activated", iClient);
    } else {
        /**
         * If Client Solomode is activated
         * Remove from RED/BLUE Solo Queue if client is found
         */
        if (iTeam == 2) {
            int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
        }
        if (iTeam == 3) {
            int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hBlueQueue, GetClientUserId(iClient));
        }
        /**
         * Disable Solo Mode for Client
         */
        SoloPlayer[iClient].bSoloMode = false;
        SoloPlayer[iClient].bCanSoloCommand = false;
        CPrintToChatAll("%t", "Command_Solo_Deactivated", iClient);
    }
    return Plugin_Handled;
}

public void OnClientDisconnect(int iClient) {
    /**
     * If Client is Connected & is a Bot -> cancel
     */
    if (IsClientConnected(iClient) && IsFakeClient(iClient)) return;
    /**
     * If Client is not In Game -> cancel
     */
    if (!IsClientInGame(iClient)) return;

    int iTeam = GetClientTeam(iClient);
    /**
     * If Client Team is RED or BLUE, remove him from SOLO queue
     */
    if (iTeam == 2) {
        int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
    }
    if (iTeam == 3) {
        int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
        if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
    }
}

public void OnMapEnd() {
    bMapChanged = true;
}

public void OnMapStart() {
    ClearArray(hRedQueue);
    ClearArray(hBlueQueue);
    CreateTimer(10.0, MapStartTimer);
    bSoloRoundStart = false;
}

public Action MapStartTimer(Handle hTimer) {
    bMapChanged = false;
    return Plugin_Handled;
}
public Action PlayerDeathEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (IsFakeClient(iClient)) return Plugin_Handled;

    int iTeam = GetClientTeam(iClient);
    if (iTeam == 2 && GetArraySize(hRedQueue) == 0) return Plugin_Handled;
    if (iTeam == 3 && GetArraySize(hBlueQueue) == 0) return Plugin_Handled;

    if (iTeam == 2 && GetRedAlivePlayerCount()) {
        if (FindValueInArray(hRedQueue, GetClientUserId(iClient)) == -1) {
            int iFirstClient = GetClientOfUserId(GetArrayCell(hRedQueue, 0));
            TF2_RespawnPlayer(iFirstClient);
            ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
        } else {
            int iNextIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient)) + 1;
            if (iNextIndex >= GetArraySize(hRedQueue)) return Plugin_Handled;
            else {
                int iNextClient = GetClientOfUserId(GetArrayCell(hRedQueue, iNextIndex));
                TF2_RespawnPlayer(iNextClient);
                ClientCommand(iNextClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        }
    }
    if (iTeam == 3 && GetBlueAlivePlayerCount() == 1) {
        if (FindValueInArray(hBlueQueue, GetClientUserId(iClient)) == -1) {
            int iFirstClient = GetClientOfUserId(GetArrayCell(hBlueQueue, 0));
            TF2_RespawnPlayer(iFirstClient);
            ClientCommand(iFirstClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
        } else {
            int iNextIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient)) + 1;
            if (iNextIndex >= GetArraySize(hBlueQueue)) return Plugin_Handled;
            else {
                int iNextClient = GetClientOfUserId(GetArrayCell(hBlueQueue, iNextIndex));
                TF2_RespawnPlayer(iNextClient);
                ClientCommand(iNextClient, "playgamesound \"%s\"", "ambient\\alarms\\doomsday_lift_alarm.wav");
            }
        }
    }
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
        char sName[32];
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
        CPrintToChatAll("%t", "RoundStart_SoloPlayers");
    bSoloRoundStart = true;
    for (int i = 1; i < MaxClients; i++) {
        if (SoloPlayer[i].bSoloMode) {
            if (GetClientTeam(i) == 2)
                SoloPlayer[i].iDeaths = GetRedAlivePlayerCount() + (FindValueInArray(hRedQueue, GetClientUserId(i)) - 1);
            if (GetClientTeam(i) == 3)
                SoloPlayer[i].iDeaths = GetBlueAlivePlayerCount() + (FindValueInArray(hBlueQueue, GetClientUserId(i)) - 1);
        }
    }
    return Plugin_Handled;
}
public Action PlayerTeamEvent(Handle hEvent, char[] sName, bool bDontBroadcast) {
    int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (IsClientConnected(iClient) && IsFakeClient(iClient)) return Plugin_Handled;
    if (SoloPlayer[iClient].bSoloMode) {
        int iTeam = GetEventInt(hEvent, "team");
        int iOldTeam = GetEventInt(hEvent, "oldteam");
        if (iTeam == 0) {
            if (iOldTeam == 2) {
                int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            }
            if (iOldTeam == 3) {
                int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
                if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            }
        }
        if (iTeam == 2 && iOldTeam == 3) {
            int iIndex = FindValueInArray(hBlueQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hBlueQueue, iIndex);
            PushArrayCell(hRedQueue, GetClientUserId(iClient));
        }
        if (iTeam == 3 && iOldTeam == 2) {
            int iIndex = FindValueInArray(hRedQueue, GetClientUserId(iClient));
            if (iIndex != -1) RemoveFromArray(hRedQueue, iIndex);
            PushArrayCell(hBlueQueue, GetClientUserId(iClient));
        }
    }
    return Plugin_Handled;
}

public void OnGameFrame() {
    if (!bMapChanged && GetTeamClientCount(2) <= 1 && GetTeamClientCount(3) <= 1) {
        if (GetArraySize(hRedQueue) != 0) ClearArray(hRedQueue);
        if (GetArraySize(hBlueQueue) != 0) ClearArray(hBlueQueue);
        for (int i = 1; i < MaxClients; i++) {
            if (SoloPlayer[i].bSoloMode) SoloPlayer[i].bSoloMode = false;
            if (SoloPlayer[i].bCanSoloCommand) SoloPlayer[i].bCanSoloCommand = false;
        }
    }
    if (!bMapChanged && GetTeamClientCount(2) > 0 && GetTeamClientCount(2) == GetArraySize(hRedQueue)) {

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
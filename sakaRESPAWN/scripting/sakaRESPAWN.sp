#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <tf2>
#include <multicolors>

#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"sakaRESPAWN"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Respawn any Player"
#define PLUGIN_URL 			"https://tf2.l03.dev/"

public Plugin myinfo ={
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart() {
	PrintToServer("[sakaRESPAWN] Enabling Plugin (%s)", PLUGIN_VERSION);
	LoadTranslations("sakarespawn.phrases.txt");
	RegAdminCmd("sm_respawn", RespawnCommand, ADMFLAG_KICK);
}

public void OnPluginEnd() {
    PrintToServer("[sakaRESPAWN] Disabling Plugin");
}

public bool IsEntityConnectedClient(int iEntity) {
	return 0 < iEntity <= MaxClients && IsClientInGame(iEntity);
}

public Action RespawnCommand(int iClient, int iArgs) {	
	if (iArgs == 1) {
		
		char sTarget[MAX_NAME_LENGTH]; 
		GetCmdArg(1, sTarget, sizeof(sTarget)); 
		if (StrEqual(sTarget, "lp", false) || StrEqual(sTarget, "listplayers", false)){
			CPrintToChat(iClient, "%t", "Command_ListPlayers_Start");
			for (int client = 0; client <= MaxClients; client++) {
				if (IsEntityConnectedClient(client) && !IsFakeClient(client)) {
					CPrintToChat(iClient, "%t", "Command_ListPlayers_Entry", client, client);
				}
			}
			CPrintToChat(iClient, "%t", "Command_ListPlayers_End");
		} else {
			char sTargetName[MAX_TARGET_LENGTH]; 
			int iTargetList[MAXPLAYERS]; 
			int iTargetCount; 
			bool bTnIsMl; 
			if ((iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), bTnIsMl)) <= 0) {
				int iBackupTarget = StringToInt(sTarget);
				if (!IsEntityConnectedClient(iBackupTarget) || IsFakeClient(iBackupTarget)) {
					CPrintToChat(iClient, "%t", "Command_NoUserFound");
					return Plugin_Handled;
				}
				iTargetList[0] = iBackupTarget;
			} 
			if (iTargetCount > 1) {
				CPrintToChat(iClient, "%t", "Command_NoMultipleTargets");
				return Plugin_Handled;
			} 
			int iTarget = iTargetList[0];
			TF2_RespawnPlayer(iTarget);
			CPrintToChat(iClient, "%t", "Command_RespawnSuccess", iTarget, iTarget);			
		}
	} else {
		CPrintToChat(iClient, "%t", "Command_Usage");
	}	
	return Plugin_Handled;
}
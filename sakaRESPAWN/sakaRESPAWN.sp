#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>

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
	RegAdminCmd("sm_respawn", RespawnCommand, ADMFLAG_KICK);
	PrintToServer("[sakaRESPAWN] Enabling Plugin (%s)", PLUGIN_VERSION);
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
		char sTargetName[MAX_TARGET_LENGTH]; 
		int iTargetList[MAXPLAYERS]; 
		int iTargetCount; 
		bool bTnIsMl; 
		if ((iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), bTnIsMl)) <= 0) {
            int iBackupTarget = StringToInt(sTarget);
            if (!IsEntityConnectedClient(iBackupTarget) || IsFakeClient(iBackupTarget)) {
                CPrintToChat(iClient, "{mediumpurple}ʀᴇsᴘᴀᴡɴ {black}» {red}No matching user found.");
                return Plugin_Handled;
            }
            iTargetList[0] = iBackupTarget;
        } 
		if (iTargetCount > 1) {
            CPrintToChat(iClient, "{mediumpurple}ʀᴇsᴘᴀᴡɴ {black}» {red}Can't process more than 1 User");
            return Plugin_Handled;
        } 
		if (StrEqual(sTarget, "lp", false) || StrEqual(sTarget, "listplayers", false)){
			CReplyToCommand(iClient, "{mediumpurple}ʀᴇsᴘᴀᴡɴ {black}» {default}List of connected Players | Start");
			for (int client = 0; client <= MaxClients; client++) {
				if (IsEntityConnectedClient(client) && !IsFakeClient(client)) {
					CReplyToCommand(iClient, "{black}» {default}Client Index: {dodgerblue}%i {default}Nickname: {dodgerblue}%N", client, client);
				}
			}
			CReplyToCommand(iClient, "{mediumpurple}ʀᴇsᴘᴀᴡɴ {black}» {default}List of connected Players | End");
		} else {
			int iTarget = iTargetList[0];
			TF2_RespawnPlayer(iTarget);
			CReplyToCommand(iClient, "{mediumpurple}ʀᴇsᴘᴀᴡɴ {black}» {default}Respawning {dodgerblue}%N{default} ({dodgerblue}%i{default})", iTarget, iTarget);
		}
	} else {
		CReplyToCommand(iClient, "{mediumpurple}ʀᴇsᴘᴀᴡɴ {black}» {default}Usage: /respawn <name|#id|index|listplayers>");
	}	
	return Plugin_Handled;
}
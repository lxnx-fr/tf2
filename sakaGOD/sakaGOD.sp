#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <multicolors>

#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"sakaGOD"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Change God Mode State"
#define PLUGIN_URL 			"https://tf2.l03.dev/"

enum struct PlayerInfo {
	bool bInGodMode;
}
PlayerInfo GodPlayer[MAXPLAYERS+1];

public Plugin myinfo ={
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart() {
	PrintToServer("[sakaGOD] Enabling Plugin (Version %s)", PLUGIN_VERSION);
	RegAdminCmd("sm_god", GodCommand, ADMFLAG_KICK);
}
public void OnPluginEnd() {
	PrintToServer("[sakaGOD] Disabling Plugin");
}


public Action GodCommand(int iClient, int iArgs) {
	if (iArgs == 0) {
		char sName[MAX_NAME_LENGTH];
		GetClientName(iClient, sName, sizeof(sName));
		if (GodPlayer[iClient].bInGodMode) {
			GodPlayer[iClient].bInGodMode = false;
			CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {default}You disabled Godmode for yourself.");
			return Plugin_Handled;
		} else {
			GodPlayer[iClient].bInGodMode = true;
			CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {default}You enabled Godmode for yourself.");
			return Plugin_Handled;
		}
	} else if (iArgs == 1) {
		char sTarget[MAX_NAME_LENGTH]; 
		GetCmdArg(1, sTarget, sizeof(sTarget)); 
		char sTargetName[MAX_TARGET_LENGTH]; 
		int iTargetList[MAXPLAYERS]; 
		int iTargetCount; 
		bool bTnIsMl; 
		if ((iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), bTnIsMl)) <= 0) {
            int iBackupTarget = StringToInt(sTarget);
            if (StrContains(sTarget, "STEAM_", false) != -1) {
                /* steamid as target given */
                char sSteamId[64];
                Format(sSteamId, sizeof(sSteamId), "%s", sTarget);
                ReplaceString(sSteamId, sizeof(sSteamId), "+", ":", false);
                /* format to correct steamid & setting it as target for the client */
                /* setting command target to -1 if no online player was found */
                iTargetList[0] = GetPlayerIndex(sSteamId);
                
            } else if (IsEntityConnectedClient(iBackupTarget) && !IsFakeClient(iBackupTarget))  {
                /* client index as target given -> setting command target to client index */
                iTargetList[0] = iBackupTarget;
            } else {
                /* no matching client index / client id / client name or steamid found -> abort */
                CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {red}No matching user found with: {dodgerblue}%s", sTarget);
                return Plugin_Handled;
			}
        }
        /* if target count is over 1: abort */ 
		if (iTargetList[0] == -1) {
			CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {red}No matching user found with: {dodgerblue}%s", sTarget);
			return Plugin_Handled;
		}
		if (iTargetCount > 1) {
            CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {red}No multiple targets");
            return Plugin_Handled;
        }
		if (GodPlayer[iTargetList[0]].bInGodMode) {
			ywGodPlayer[iTargetList[0]].bInGodMode = false;
			CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {default}You disabled Godmode for {dodgerblue}%N", iTargetList[0]);
			return Plugin_Handled;
		} else {
			GodPlayer[iTargetList[0]].bInGodMode = true;
			CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {default}You enabled Godmode for %N.", iTargetList[0]);
			return Plugin_Handled;
		}
	} else {
		CPrintToChat(iClient, "{mediumpurple}ɢᴏᴅ {black}» {default}Wrong usage! {red}/god [name|#id|index|steamid]");
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int iClient) {
	if (IsEntityConnectedClient(iClient)) {
		SDKHook(iClient, SDKHook_OnTakeDamage, OnClientTakesDamage);
	}
}
public Action OnClientTakesDamage(int iVictim, int& iAttacker, int& iInflictor, float& fDamage, int& iDamageType, int& iWeapon, float damageForce[3], float damagePosition[3]) {
	if (GodPlayer[iVictim].bInGodMode) {
		if (IsEntityConnectedClient(iVictim)) {
			fDamage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}
stock bool IsEntityConnectedClient(int iEntity) {
	return (0 < iEntity <= MaxClients && IsClientInGame(iEntity));
}
stock char[] GetSteamId(int iClient) {
	char sSteamId[32];
	if (IsClientConnected(iClient) && !IsFakeClient(iClient)) {
		GetClientAuthId(iClient, AuthId_Steam2, sSteamId, sizeof(sSteamId), true);
	}
	return sSteamId;
}
stock int GetPlayerIndex(char[] sSteamId) {
    int iPlayerIndex = -1; 
    for (int iClient = 0; iClient <= MAXPLAYERS; iClient++) {
        if (IsEntityConnectedClient(iClient) && !IsFakeClient(iClient)) {
            if (StrEqual(GetSteamId(iClient), sSteamId, true)) {
                return iClient;
            }
        }
    }
    return iPlayerIndex;
}
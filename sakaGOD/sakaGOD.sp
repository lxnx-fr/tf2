#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>

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
	RegAdminCmd("sm_god", GodCommand, ADMFLAG_KICK);
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
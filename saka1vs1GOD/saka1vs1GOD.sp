#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"saka1vs1GOD"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Auto God Mode for 1vs1"
#define PLUGIN_URL 			"https://tf2.l03.dev/"
#define LIMIT 2

public Plugin myinfo ={
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

bool b1vs1Enabled = false;

public void OnPluginStart() { 
	HookEvent("player_team", OnChangeTeam, EventHookMode_PostNoCopy);  
	HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy); 
	for (int i = 0; i <= MAXPLAYERS; i++) {
		if (IsEntityConnectedClient(i) && !IsFakeClient(i)) {
			SDKHook(i, SDKHook_OnTakeDamage, OnClientTakesDamage);
		}
	}
}
public void OnClientPutInServer(int iClient) {
	if (IsEntityConnectedClient(iClient)) {
		SDKHook(iClient, SDKHook_OnTakeDamage, OnClientTakesDamage);
	}
}
public void OnChangeTeam(Event hEvent, const char[] sName, bool bDontBroadcast) {
	RequestFrame(DelayCheck);
}
public void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast) {
	CheckGodmodeStatus();
}
public void OnClientDisconnect(int iClient) {
	CheckGodmodeStatus();
}
public void DelayCheck() {
	CheckGodmodeStatus();
}
public Action OnClientTakesDamage(int iVictim, int& iAttacker, int& iInflictor, float& fDamage, int& iDamageType, int& iWeapon, float damageForce[3], float damagePosition[3]) {
	if (b1vs1Enabled) {
		if (IsEntityConnectedClient(iVictim)) {
			fDamage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}
public void CheckGodmodeStatus() {
	int iPlayers = GetTeamClientCount(2) + GetTeamClientCount(3);
	if (iPlayers == LIMIT) {
		b1vs1Enabled = true;
		return;
	}
	b1vs1Enabled = false;
}
stock bool IsEntityConnectedClient(int iEntity) {
	return (0 < iEntity <= MaxClients && IsClientInGame(iEntity));
}

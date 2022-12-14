#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <morecolors>

#define COMMAND_DELAY   	0.250
#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"sakaTP"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Change Thirdperson and Firstperson"
#define PLUGIN_URL 			"https://tf2.l03.dev/"

Handle hDefaultView = INVALID_HANDLE;
bool gInThirdperson[MAXPLAYERS + 1];

public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart() {
	hDefaultView = CreateConVar("sm_tp_default", "0", "Set default view (0 firstperson, 1 thirdperson, def. 0)");
	RegConsoleCmd("sm_firstperson", FirstPersonCommand);
	RegConsoleCmd("sm_thirdperson", ThirdPersonCommand);
	RegConsoleCmd("sm_fp", FirstPersonCommand);
	RegConsoleCmd("sm_tp", ThirdPersonCommand);
	HookEvent("player_class", PlayerSpawnEvent);
	HookEvent("player_spawn", PlayerSpawnEvent);
	HookEvent("teamplay_round_start", RoundStartEvent);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	MarkNativeAsOptional("GetUserMessageType");
	return APLRes_Success;
}

public Action PlayerSpawnEvent(Handle hEvent, const char[] name, bool dontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	CreateTimer(COMMAND_DELAY, ThirdPersonOnSpawn, iClient);
	return Plugin_Handled;
}

public Action ThirdPersonOnSpawn(Handle hTimer, int iClient) {
	if (IsClientInGame(iClient) && gInThirdperson[iClient] && IsPlayerAlive(iClient)) {
		SetThirdPersonView(iClient);
	}
	return Plugin_Handled;
}

public Action RoundStartEvent(Handle hEvent, const char[] name, bool dontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		CreateTimer(COMMAND_DELAY, ThirdPersonOnSpawn, i);
	}
	return Plugin_Handled;
}

public void OnClientConnected(int iClient) {
	gInThirdperson[iClient] = GetConVarBool(hDefaultView);
}

public Action FirstPersonCommand(int iClient, int iArgs) {
	if (iClient == 0) {
		CReplyToCommand(iClient, "{mediumpurple}ғᴘ {black}» {default}Command is in-game only");
		return Plugin_Handled;
	}
	FirstPersonRequest(iClient);
	return Plugin_Handled;
}

public Action ThirdPersonCommand(int iClient, int iArgs) {
	if (iClient == 0) {
		CReplyToCommand(iClient, "{mediumpurple}ᴛᴘ {black}» {default}Command is in-game only");
		return Plugin_Handled;
	}
	ThirdPersonRequest(iClient);
	return Plugin_Handled;
}

public void SetThirdPersonView(int iClient) {
	gInThirdperson[iClient] = true;
	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
}

public void SetFirstPersonView(int iClient) {
	gInThirdperson[iClient] = false;
	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
}

public void ThirdPersonRequest(int iClient) {
	if (gInThirdperson[iClient]) {
		CReplyToCommand(iClient, "{mediumpurple}ᴛᴘ {black}» {default}Thirdperson is already enabled.");
	} else {
		SetThirdPersonView(iClient);
		CReplyToCommand(iClient, "{mediumpurple}ᴛᴘ {black}» {default}Thirdperson enabled.");
	}
}

public void FirstPersonRequest(int iClient) {
	if (!gInThirdperson[iClient]) {
		CReplyToCommand(iClient, "{mediumpurple}ғᴘ {black}» {default}Firstperson is already enabled.");
	} else {
		SetFirstPersonView(iClient);
		CReplyToCommand(iClient, "{mediumpurple}ғᴘ {black}» {default}Firstperson enabled.");
	}
}

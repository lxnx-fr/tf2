#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#undef REQUIRE_EXTENSIONS
#include <tf2>

#define PLUGIN_VERSION	"1.2.0"

public Plugin myinfo = {
	name		= "sakaFOV",
	author		= "Dr. McKay",
	description	= "Allows players to choose their own FOV",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

Handle cookieFOV;
Handle cvarFOVMin;
Handle cvarFOVMax;

#define CONVAR_PREFIX	"ufov"

public void OnPluginStart() {
	cookieFOV = RegClientCookie("unrestricted_fov", "Client Desired FOV", CookieAccess_Private);
	
	cvarFOVMin = CreateConVar("ufov_min", "20", "Minimum FOV a client can set with the !fov command", _, true, 20.0, true, 180.0);
	cvarFOVMax = CreateConVar("ufov_max", "130", "Maximum FOV a client can set with the !fov command", _, true, 20.0, true, 180.0);
	
	RegConsoleCmd("sm_fov", Command_FOV);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Command_FOV(int client, int args) {
	
	if(!AreClientCookiesCached(client)) {
		CReplyToCommand(client, "{mediumpurple}ғᴏᴠ {black}» {red}This command is currently unavailable. Please try again later.");
		return Plugin_Handled;
	}
	
	if (args >= 1) {
		char sFov[32];
		GetCmdArg(1, sFov, sizeof(sFov));
		int fov = StringToInt(sFov);
		if(fov < GetConVarInt(cvarFOVMin)) {
			QueryClientConVar(client, "fov_desired", OnFOVQueried);
			CReplyToCommand(client, "{mediumpurple}ғᴏᴠ {black}» {default}The minimum FOV you can set is {dodgerblue}%i", GetConVarInt(cvarFOVMin));
			return Plugin_Handled;
		}
		if(fov > GetConVarInt(cvarFOVMax)) {
			QueryClientConVar(client, "fov_desired", OnFOVQueried);
			CReplyToCommand(client, "{mediumpurple}ғᴏᴠ {black}» {default}The maximum FOV you can set is {dodgerblue}%i", GetConVarInt(cvarFOVMax));
			return Plugin_Handled;
		}
		char cookie[12];
		IntToString(fov, cookie, sizeof(cookie));
		SetClientCookie(client, cookieFOV, cookie);
	
		SetEntProp(client, Prop_Send, "m_iFOV", fov);
		SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
		CReplyToCommand(client, "{mediumpurple}ғᴏᴠ {black}» {default}Your FOV has been set to {dodgerblue}%i {default}on this server.", fov);
	} else {
		QueryClientConVar(client, "fov_desired", OnFOVQueried);
		CReplyToCommand(client, "{mediumpurple}ғᴏᴠ {black}» {default}Your FOV has been reset.");
	}
	return Plugin_Handled;
}


public Action Event_PlayerSpawn(Handle event, char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!AreClientCookiesCached(client)) {
		return Plugin_Continue;
	}
	
	char cookie[12];
	GetClientCookie(client, cookieFOV, cookie, sizeof(cookie));
	int fov = StringToInt(cookie);
	if(fov < GetConVarInt(cvarFOVMin) || fov > GetConVarInt(cvarFOVMax)) {
		return Plugin_Continue;
	}
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
	if(condition != TFCond_TeleportedGlow) {
		return;
	}
	char cookie[12];
	GetClientCookie(client, cookieFOV, cookie, sizeof(cookie));
	int fov = StringToInt(cookie);
	if(fov < GetConVarInt(cvarFOVMin) || fov > GetConVarInt(cvarFOVMax)) {
		return;
	}
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
}
public void TF2_OnConditionRemoved(int client, TFCond condition) {
	if(condition != TFCond_Zoomed) {
		return;
	}
	char cookie[12];
	GetClientCookie(client, cookieFOV, cookie, sizeof(cookie));
	int fov = StringToInt(cookie);
	if(fov < GetConVarInt(cvarFOVMin) || fov > GetConVarInt(cvarFOVMax)) {
		return;
	}
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
}

public void OnFOVQueried(QueryCookie cookie, int client, ConVarQueryResult result, char[] cvarName, char[] cvarValue) {
	if(result != ConVarQuery_Okay) {
		return;
	}
	SetClientCookie(client, cookieFOV, "");
	SetEntProp(client, Prop_Send, "m_iFOV", StringToInt(cvarValue));
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", StringToInt(cvarValue));
}
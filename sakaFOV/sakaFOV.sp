#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <clientprefs>
#include <tf2>

#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"sakaFOV"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION 	"Change Field of View"
#define PLUGIN_URL 			"https://tf2.l03.dev/"

public Plugin myinfo = {
  name = PLUGIN_NAME,
  author = PLUGIN_AUTHOR,
  description = PLUGIN_DESCRIPTION,
  version = PLUGIN_VERSION,
  url = PLUGIN_URL
};

Handle hFOVCookie;

public void OnPluginStart() {
	PrintToServer("[sakaFOV] Enabling Plugin (Version %s)", PLUGIN_VERSION);
	hFOVCookie = RegClientCookie("unrestricted_fov", "Client Desired FOV", CookieAccess_Private);
	RegConsoleCmd("sm_fov", FovCommand);
	HookEvent("player_spawn", PlayerSpawnEvent);
}

public void OnPluginEnd() {
	UnhookEvent("player_spawn", PlayerSpawnEvent);
	PrintToServer("[sakaFOV] Disabling Plugin");
}


public Action FovCommand(int iClient, int iArgs) {
	char sFOV[12];
	GetCmdArg(1, sFOV, sizeof(sFOV));  	
	int iFov = StringToInt(sFOV); 
	if (!AreClientCookiesCached(iClient)) {
		CReplyToCommand(iClient, "{mediumpurple}ғᴏᴠ {black}» {ancient}This command is currently unavailable. Please try again later.");
		return Plugin_Handled;
	} 
	if(iArgs == 0) {
		QueryClientConVar(iClient, "fov_desired", OnFOVQueried);
		CReplyToCommand(iClient, "{mediumpurple}ғᴏᴠ {black}» {default}Your FOV has been reset.");
		return Plugin_Handled;
	} 
	if(iFov < 30) {
		QueryClientConVar(iClient, "fov_desired", OnFOVQueried);
		CReplyToCommand(iClient, "{mediumpurple}ғᴏᴠ {black}» {default}The minimum FOV you can set  is {dodgerblue}30{default}.");
		return Plugin_Handled;
	}
	if(iFov > 130) {
		QueryClientConVar(iClient, "fov_desired", OnFOVQueried);
		CReplyToCommand(iClient, "{mediumpurple}ғᴏᴠ {black}» {default}The maximum FOV you can set is {dodgerblue}150{default}.");
		return Plugin_Handled;
	}
	char sCookie[12];
	IntToString(iFov, sCookie, sizeof(sCookie));
	SetClientCookie(iClient, hFOVCookie, sCookie);
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFov);
	CReplyToCommand(iClient, "{mediumpurple}ғᴏᴠ {black}» {default}Your FOV has been set to {dodgerblue}%d{default} on this server.", iFov);
	return Plugin_Handled;
}


public Action PlayerSpawnEvent(Handle event, const char[] name, bool dontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!AreClientCookiesCached(iClient)) {
		return Plugin_Handled;
	}
	char sCookie[12];
	GetClientCookie(iClient, hFOVCookie, sCookie, sizeof(sCookie));
	int iFov = StringToInt(sCookie);
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFov);
	return Plugin_Handled;
}

public void TF2_OnConditionAdded(int iClient, TFCond condition) {
	if(condition != TFCond_TeleportedGlow) {
		return;
	}
	char sCookie[12];
	GetClientCookie(iClient, hFOVCookie, sCookie, sizeof(sCookie));
	int iFov = StringToInt(sCookie);
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFov);
}
public void TF2_OnConditionRemoved(int iClient, TFCond condition) {
	if(condition != TFCond_Zoomed) {
		return;
	}
	char sCookie[12];
	GetClientCookie(iClient, hFOVCookie, sCookie, sizeof(sCookie));
	int iFov = StringToInt(sCookie);
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFov);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFov);
}

public void OnFOVQueried(QueryCookie cookie, int iClient, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue) {
	if(result != ConVarQuery_Okay) {
		return;
	}
	SetClientCookie(iClient, hFOVCookie, "");
	SetEntProp(iClient, Prop_Send, "m_iFOV", StringToInt(cvarValue));
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", StringToInt(cvarValue));
}
#pragma semicolon 1
#pragma newdecls required



#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>
#include <tf2attributes>
#include <clientprefs>

#define PLUGIN_VERSION "1.0"
#define PLUGIN_NAME "sakaFOOTPRINTS"
#define PLUGIN_AUTHOR "ѕαĸα"
#define PLUGIN_DESCRIPTION "Custom Footprints"
#define PLUGIN_URL "https://tf2.l03.dev/"

Handle hFootprintCookie;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	PrintToServer("[sakaFPRINTS] Enabling Plugin (Version %s)", PLUGIN_VERSION); 
	RegConsoleCmd("sm_cfp", FootPrintCommand); 
	RegConsoleCmd("sm_footprints", FootPrintCommand);
	HookEvent("player_spawn", PlayerSpawnEvent); 
	hFootprintCookie = RegClientCookie("sFootprint","ActiveFootprint", CookieAccess_Private); 
}

public void OnPluginEnd() {
	PrintToServer("[sakaFPRINTS] Disabling Plugin");
}

public bool IsEntityConnectedClient(int iEntity) {
	return 0 < iEntity <= MaxClients && IsClientInGame(iEntity);
}

public Action PlayerSpawnEvent(Handle event, const char[] cName, bool dontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(event, "userid")); 
	if(!AreClientCookiesCached(iClient)) {
	 	SetClientCookie(iClient, hFootprintCookie, "0");
	 } 
	char cFootprintCookie[24];
	GetClientCookie(iClient, hFootprintCookie, cFootprintCookie, sizeof(cFootprintCookie)); 
	float fActiveFootprint = StringToFloat(cFootprintCookie);
	if(fActiveFootprint > 0.0){
		TF2Attrib_SetByName(iClient, "SPELL: set Halloween footstep type", fActiveFootprint);
	}
	return Plugin_Handled;
}

public Action FootPrintCommand(int iClient, int iArgs) {
	if (iArgs == 1) {
		char sFootprint[12];
		GetCmdArg(1, sFootprint, sizeof(sFootprint));
		float fFootprint = StringToFloat(sFootprint);
		SetClientCookie(iClient, hFootprintCookie, sFootprint);
		if(fFootprint == 0.0){
			TF2Attrib_RemoveByName(iClient, "SPELL: set Halloween footstep type");
		} else {
			TF2Attrib_SetByName(iClient, "SPELL: set Halloween footstep type", fFootprint);
		}
		CPrintToChat(iClient, "{mediumpurple}ғᴏᴏᴛᴘʀɪɴᴛs {black}» {default}Set your Footprint to {dodgerblue}%.0f{default}.", fFootprint);
	} else {
		DrawFootprintMenu(iClient);	
	} 
	return Plugin_Handled;
}

public void DrawFootprintMenu(int iClient) { 
	Handle ws = CreateMenu(FootPrintMenuHandle);  
	Menu menu = new Menu(FootPrintMenuHandle);
	menu.SetTitle("Footprints Menu");
	SetMenuTitle(ws, "Footprints Menu");
	menu.AddItem("0", "No Effect");
	menu.AddItem("X", "", ITEMDRAW_DISABLED);
	menu.AddItem("1", "Team Based");
	menu.AddItem("7777", "Blue");
	menu.AddItem("933333", "Light Blue");
	menu.AddItem("8421376", "Yellow");
	menu.AddItem("4552221", "Corrupted Green");
	menu.AddItem("3100495", "Dark Green");
	menu.AddItem("51234123", "Lime");
	menu.AddItem("5322826", "Brown");
	menu.AddItem("8355220", "Oak Tree Brown");
	menu.AddItem("13595446", "Flames");
	menu.AddItem("8208497", "Cream");
	menu.AddItem("41234123", "Pink");
	menu.AddItem("300000", "Satan's Blue");
	menu.AddItem("2", "Purple");
	menu.AddItem("3", "4 8 15 16 23 42");
	menu.AddItem("83552", "Ghost In The Machine");
	menu.AddItem("9335510", "Holy Flame");
	menu.AddItem("645", "Teddo ");
	menu.AddItem("323", "Polenta");
	menu.AddItem("32232", "Universe");
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}  
public int FootPrintMenuHandle(Handle menu, MenuAction action, int iClient, int iItem){ 
	if(action == MenuAction_End) CloseHandle(menu);
	if(action == MenuAction_Select) {
		char cInfo[24];
		GetMenuItem(menu, iItem, cInfo, sizeof(cInfo));
		float fActiveFootprint = StringToFloat(cInfo); 
		SetClientCookie(iClient, hFootprintCookie, cInfo);
		if(fActiveFootprint == 0.0){
			TF2Attrib_RemoveByName(iClient, "SPELL: set Halloween footstep type");
		} else {
			TF2Attrib_SetByName(iClient, "SPELL: set Halloween footstep type", fActiveFootprint);
		}
	}
	return 0;
}

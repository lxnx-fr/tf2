#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>
#include <tf2attributes>
// ^ tf2_stocks.inc itself includes sdktools.inc and tf2.inc
#include <dbi>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_NAME "sakaSTORE"
#define PLUGIN_AUTHOR "ѕαĸα"
#define PLUGIN_DESCRIPTION "Store/Shop Plugin"

enum struct StoreInfo {
	float fActiveFootprint;

}

StoreInfo StorePlayer[MAXPLAYERS + 1];
Handle DB_KEYVALUES = INVALID_HANDLE;
Handle DB = INVALID_HANDLE;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://l03.dev/"
};

public void OnPluginStart() {
	PrintToServer("[sakaSTORE] Plugin is starting...");
    initConVars();
	//initDatabase(true);
    RegConsoleCmd("sm_menu", StoreCommand);
    RegConsoleCmd("sm_cfp", FootPrintCommand);
    HookEvent("player_spawn", PlayerSpawnEvent);
}

public int PlayerMoney(int iClient) {
	int iMoney = -1;
	char queryString[255];
	Format(queryString, sizeof(queryString), "SELECT money FROM sakaStats WHERE steamid = '%s';", GetSteamId(iClient));
	DBResultSet query = SQL_Query(DB, queryString);
	if (query == null) {
		char error[255];
		SQL_GetError(DB, error, sizeof(error));
		PrintToServer("[sakaSTORE] PlayerMoney: Failed to query (error: %s)", error);
	} else {
		SQL_FetchRow(query);
		iMoney = SQL_FetchInt(query, 0);
	}

}

public bool IsEntityConnectedClient(int entity) {
	return 0 < entity <= MaxClients && IsClientInGame(entity);
}

stock char[] GetSteamId(int client) {
	char SteamID[32];
	if (IsEntityConnectedClient(client)) {
		GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID), true);
	}
	return SteamID;
}

public void OnPluginEnd() {
	
    //initDatabase(false);
    UnhookEvent("player_spawn", PlayerSpawnEvent);
	PrintToServer("[sakaSTORE] Plugin is ending...");
}


public void LoadPlayerFromDB(int iClient) {
	if (!IsEntityConnectedClient(iClient) || IsFakeClient(iClient)) return;

}

public void LoadPlayerToDB(int iClient) {
	if (!IsEntityConnectedClient(iClient) || IsFakeClient(iClient)) return;

}

public void OnClientDisconnect(int iClient){

	if(StorePlayer[iClient].fActiveFootprint > 0.0) {
		StorePlayer[iClient].fActiveFootprint = 0.0;
	}
}

public Action PlayerSpawnEvent(Handle event, const char[] cName, bool dontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(StorePlayer[iClient].fActiveFootprint > 0.0){
		TF2Attrib_SetByName(iClient, "SPELL: set Halloween footstep type", StorePlayer[iClient].fActiveFootprint);
	}
}

public void initConVars() {
	CreateConVar("sakastore_version", PLUGIN_VERSION, "Standard plugin version ConVar.", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	DB_KEYVALUES = CreateKeyValues("database");
	KvSetString(DB_KEYVALUES, "host", "plesk12.zap-webspace.com");
	KvSetString(DB_KEYVALUES, "database", "dodgeball");
	KvSetString(DB_KEYVALUES, "user", "tf2server");
	KvSetString(DB_KEYVALUES, "pass", "38~68Toni");
}

public void initDatabase(bool connect) {
	char error[255];
	if (connect) {
		DB = SQL_ConnectCustom(DB_KEYVALUES, error, sizeof(error), false);
		if (DB == INVALID_HANDLE) {
	    	PrintToServer("[sakaSTORE] Could not connect to datebase: %s", error);
	    	CloseHandle(DB);
		}
		PrintToServer("[sakaSTORE] Connecting to database");
		if (!SQL_FastQuery(DB, "CREATE TABLE IF NOT EXISTS sakaSTORE (steamid VARCHAR(100), footprintId INT, );")) {
			char error[255];
			SQL_GetError(DB, error, sizeof(error));
			PrintToServer("[sakaSTORE] initDatabase: failed to query (error: %s)",error);
		}
	} else {
		delete DB;
		PrintToServer("[sakaSTORE] Disconnecting from database");
	}
}


public Action StoreCommand(int iClient, int iArgs) {
    DrawMainMenu(iClient);
    return Plugin_Handled;
}

 public void DrawMainMenu(int iClient) {
	Menu menu = new Menu(MainMenuHandle);
	menu.SetTitle("Main Menu");
	menu.AddItem("0", "Help");
	menu.AddItem("1", "Footprints");
	menu.AddItem("2", "Stats");
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MainMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch (action) {
		case MenuAction_Select: {
			char cInfo[32];
			bool bFound = menu.GetItem(iItem, cInfo, sizeof(cInfo));
			switch (iItem) {
				case 0:
				    DrawHelpMenu(iClient);
				case 1:
				    DrawFootprintMenu(iClient);
				case 2:
				    DrawStatsMenu(iClient);
			}
		}
		case MenuCancel_Exit, MenuAction_Cancel, MenuAction_End: {
			menu.Cancel();
			delete menu;
		}
	}
}

public void DrawHelpMenu(int iClient) {
	Menu menu = new Menu(StoreMenuHandle);
	menu.SetTitle("Menu | Help");
	menu.AddItem("0", "!topspeed - Show your highest speed");
	menu.AddItem("1", "!stats -");
	menu.AddItem("2", "!fov - Changes your Field of View");
	menu.AddItem("3", "!tp / !fp - Thirdperson / Firstperson");
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}


public Action FootPrintCommand(int iClient, int iArgs) {
	DrawFootprintMenu(iClient);
    return Plugin_Handled;
}



public void DrawFootprintMenu(int iClient) {
    Handle ws = CreateMenu(FootPrintMenuHandle);
	SetMenuTitle(ws, "Menu | Footprints");

	AddMenuItem(ws, "0", "No Effect");
	AddMenuItem(ws, "X", "2000 Coins per Item", ITEMDRAW_DISABLED);
	AddMenuItem(ws, "1", "Team Based");
	AddMenuItem(ws, "7777", "Blue");
	AddMenuItem(ws, "933333", "Light Blue");
	AddMenuItem(ws, "8421376", "Yellow");
	AddMenuItem(ws, "4552221", "Corrupted Green");
	AddMenuItem(ws, "3100495", "Dark Green");
	AddMenuItem(ws, "51234123", "Lime");
	AddMenuItem(ws, "5322826", "Brown");
	AddMenuItem(ws, "8355220", "Oak Tree Brown");
	AddMenuItem(ws, "13595446", "Flames");
	AddMenuItem(ws, "8208497", "Cream");
	AddMenuItem(ws, "41234123", "Pink");
	AddMenuItem(ws, "300000", "Satan's Blue");
	AddMenuItem(ws, "2", "Purple");
	AddMenuItem(ws, "3", "4 8 15 16 23 42");
	AddMenuItem(ws, "83552", "Ghost In The Machine");
	AddMenuItem(ws, "9335510", "Holy Flame");
	DisplayMenu(ws, iClient, MENU_TIME_FOREVER);
}

public int FootPrintMenuHandle(Handle menu, MenuAction action, int iClient, int iItem){
	if(action == MenuAction_End) CloseHandle(menu);
	if(action == MenuAction_Select) {
		char cInfo[12];
		GetMenuItem(menu, iItem, cInfo, sizeof(cInfo));
		float fWeaponGlow = StringToFloat(cInfo);
		StorePlayer[iClient].fActiveFootprint = fWeaponGlow;
		if(fWeaponGlow == 0.0){
			TF2Attrib_RemoveByName(iClient, "SPELL: set Halloween footstep type");
		} else {
			TF2Attrib_SetByName(iClient, "SPELL: set Halloween footstep type", fWeaponGlow);
		}
	}
}

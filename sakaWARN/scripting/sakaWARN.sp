#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <multicolors>

#define PLUGIN_VERSION 		"1.2"
#define PLUGIN_NAME 		"sakaWARN"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Warn Players"
#define PLUGIN_URL 			"https://tf2.l03.dev/"
#define SQL_QUERY_CREATE    "CREATE TABLE IF NOT EXISTS sakaWarn (id INT, steamid VARCHAR(100), name VARCHAR(100), reason VARCHAR(150), executorid VARCHAR(100), executorname VARCHAR(100), timeexecuted INT);"

public Plugin myinfo ={
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

enum struct MenuInfo {
    bool bSayHook;
    bool bInMenu;
    float fSayHookTime;
    int iSayHookType;
    int iClient;
    int iWarnId;
    int iTargetIndex;
    char sTargetName[MAX_NAME_LENGTH];
    char sSteamId[64];
    char sReason[100];
}
MenuInfo MenuPlayer[MAXPLAYERS + 1];
Handle DB = INVALID_HANDLE;

public void OnPluginStart() { 
    LoadTranslations("sakawarn.phrases.txt");
    PrintToServer("[sakaWARN] Enabling Plugin by %s (Version %s)", PLUGIN_AUTHOR, PLUGIN_VERSION); 
    InitDatabase(true); 
    RegAdminCmd("sm_warn", WarnCommand, ADMFLAG_KICK);
    RegAdminCmd("sm_addwarn", AddWarnCommand, ADMFLAG_KICK);
    RegAdminCmd("sm_listwarns", ListWarnsCommand, ADMFLAG_KICK);
}
public void OnPluginEnd() {
    PrintToServer("[sakaWARN] Disabling Plugin");
    InitDatabase(false);
}
public void InitDatabase(bool bConnect) { 
    char sError[255];  
    if (bConnect) {
        //DB = SQL_ConnectCustom(DB_KEYVALUES, sError, sizeof(sError), false);
        DB = SQL_Connect("sakawarn", true, sError, sizeof(sError));
        if (DB == INVALID_HANDLE) {
	    	PrintToServer("[sakaWARN] Could not connect to Database: %s", sError);
	    	CloseHandle(DB);
		} 
        PrintToServer("[sakaWARN] Connecting to Database..."); 
        if (!SQL_FastQuery(DB, SQL_QUERY_CREATE)) {
			SQL_GetError(DB, sError, sizeof(sError));
			PrintToServer("[sakaWARN] failed to query (error: %s)", sError);
		}
	} else {
		delete DB;
	}
}
public void OnClientConnected(int iClient) {
    MenuPlayer[iClient].bSayHook = false;
    MenuPlayer[iClient].fSayHookTime = 0.0;
    MenuPlayer[iClient].iSayHookType = 0;
    
}
public void OnClientDisconnect(int iClient) {
    MenuPlayer[iClient].bSayHook = false;
    MenuPlayer[iClient].fSayHookTime = 0.0;
    MenuPlayer[iClient].iSayHookType = 0;
    
}
public Action OnClientSayCommand(int iClient, const char[] sCommand, const char[] sArgs) {
    if (!MenuPlayer[iClient].bSayHook)
        return Plugin_Continue;
    MenuPlayer[iClient].bSayHook = false;
    if ((GetGameTime() - MenuPlayer[iClient].fSayHookTime) > 30.0) return Plugin_Continue;
    if (strcmp(sCommand, "say") != -1) {
    	switch (MenuPlayer[iClient].iSayHookType) {
    		case 1: {
                if (StrEqual(sArgs, "--c", false)) {
                    CPrintToChat(iClient, "%t", "ClientSayHookCancelled");
                    return Plugin_Stop;
                }
                int iRandomWarnId = GetRandomInt(1, 100000); 
                char sReason[100];
                strcopy(sReason, sizeof(sReason), sArgs);
                bool bNoMessage = (StrContains(sReason, "--nm", false) == -1 ? true : false);
                bool bAnonymous = (StrContains(sReason, "--a", false) == -1 ? false : true);
                if (!bNoMessage)
                    ReplaceString(sReason, sizeof(sReason), "--nm", "", false);
                if (bAnonymous)
                    ReplaceString(sReason, sizeof(sReason), "--a", "", false);
                char sTargetName[MAX_NAME_LENGTH];
                if (MenuPlayer[iClient].iTargetIndex == -1) {
                    sTargetName = GetPlayerNameFromDB(MenuPlayer[iClient].sSteamId);
                } else {
                    GetClientName(MenuPlayer[iClient].iTargetIndex, sTargetName, sizeof(sTargetName));
                }
                MenuPlayer[iClient].sTargetName = sTargetName;
                CPrintToChat(iClient, "%t", "ClientSayHookSuccess", (StrEqual(sTargetName, "[[NOTFOUND]]", false) ? MenuPlayer[iClient].sSteamId : sTargetName), iRandomWarnId);
                CPrintToChat(iClient, "%t", "ClientSayHookSuccessReason", sReason);
                AddWarnToUser(MenuPlayer[iClient].iTargetIndex, iClient, bNoMessage, bAnonymous,  sReason, iRandomWarnId); 
                return Plugin_Stop;
    		}
    	}

    }
    return Plugin_Continue;
}

stock char[] GetPlayerNameFromDB(char[] sSteamId) {
    char sName[MAX_NAME_LENGTH];
    sName = "[[NOTFOUND]]";
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT name FROM sakaWarn WHERE steamid ='%s';", sSteamId);
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaWARN] GetPlayerNameFromDB() failed to query (error: %s)", sError);
    } else {
        if(SQL_FetchRow(rsQuery)) {
            SQL_FetchString(rsQuery, 0, sName, sizeof(sName));
        }
    }

    return sName;
}

public Action WarnCommand(int iClient, int iArgs) {
    DrawWarnMainMenu(iClient);
    if (iArgs == 1) {
        char sArgOne[32];
        GetCmdArg(1, sArgOne, sizeof(sArgOne));
        if (StrEqual(sArgOne, "info", false)) {
            CReplyToCommand(iClient, "{mediumpurple}ᴡᴀʀɴ {black}» {default}Warn System by {dodgerblue}ѕαĸα {default}(Version {dodgerblue}%s{default})", PLUGIN_VERSION);
            CReplyToCommand(iClient, "{mediumpurple}ᴡᴀʀɴ {black}» {default} Commands:");
            CReplyToCommand(iClient, "{mediumpurple}ᴡᴀʀɴ {black}» {default} /warn - Warn Main Menu to Manage everything");
            CReplyToCommand(iClient, "{mediumpurple}ᴡᴀʀɴ {black}» {default} /addwarn <name|#id|index|steamid>");
            CReplyToCommand(iClient, "{mediumpurple}ᴡᴀʀɴ {black}» {default} /listwarns <name|#id|index|steamid>");
        }
    }
    return Plugin_Handled;
}
public void DrawWarnMainMenu(int iClient) {
    Menu menu = new Menu(WarnMainMenuHandle);
    menu.SetTitle("Warn Main Menu");
    menu.AddItem("0", "List Online Users");
    menu.AddItem("1", "All Time Warned Users");
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
    MenuPlayer[iClient].bInMenu = true;
}
public int WarnMainMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch(action) {
        case MenuAction_Select: {
            switch(iItem) {
                case 0: {
                    DrawOnlinePlayersMenu(iClient);
                }
                case 1: {
                    DrawAllTimePlayersMenu(iClient);
                }
            }
        }
        case MenuAction_End: {
            delete menu;
           
        }
    }
    return 0;
}
public void DrawAllTimePlayersMenu(int iClient) {
    Menu menu = new Menu(AllTimePlayersMenuHandle);
    menu.SetTitle("Alltime Player Warnings");
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT name, steamid, id FROM sakaWarn GROUP BY steamid HAVING COUNT(steamid) >= 1;");
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        delete menu;
        PrintToServer("[sakaWARN] DrawAllTimePlayersMenu() failed to query (error: %s)", sError);
    } else {
        while (SQL_FetchRow(rsQuery)) {
            char sSteamId[64];
            SQL_FetchString(rsQuery, 1, sSteamId, sizeof(sSteamId));
            char sName[MAX_NAME_LENGTH];
            SQL_FetchString(rsQuery, 0, sName, sizeof(sName));
            char sMenuText[128];
            Format(sMenuText, sizeof(sMenuText), "%s (%s)", sName, sSteamId);
            menu.AddItem(sSteamId, sMenuText);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}
public int AllTimePlayersMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            char sInfo[64];
            GetMenuItem(menu, iItem, sInfo, sizeof(sInfo));
            MenuPlayer[iClient].sSteamId = sInfo;
            MenuPlayer[iClient].sTargetName = "[[NOTFOUND]]"; 
            MenuPlayer[iClient].iTargetIndex = GetPlayerIndex(sInfo);
            DrawPlayerSettingsMenu(iClient);
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) {
                DrawWarnMainMenu(iClient);
            }
        }
        case MenuAction_End: {
            
            delete menu;
        }
    }
    return 0;
}
public void DrawOnlinePlayersMenu(int iClient) {
    Menu menu = new Menu(OnlinePlayersMenuHandle);
    menu.SetTitle("Choose a player");
    for(int iTarget = 0; iTarget <= MAXPLAYERS; iTarget++) {
        if (IsEntityConnectedClient(iTarget) && !IsFakeClient(iTarget)) {
            char sMenuText[100];
            char sTargetName[MAX_NAME_LENGTH];
            GetClientName(iTarget, sTargetName, sizeof(sTargetName));
            Format(sMenuText, sizeof(sMenuText), "#%i - %s", iTarget, sTargetName);
            menu.AddItem(GetSteamId(iTarget), sMenuText);
        }
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
    MenuPlayer[iClient].bInMenu = true;
}
public int OnlinePlayersMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            char sInfo[64];
            bool bFound = menu.GetItem(iItem, sInfo, sizeof(sInfo));
            if (bFound) {
                MenuPlayer[iClient].sSteamId = sInfo;
                MenuPlayer[iClient].sTargetName = GetOnlineName(sInfo);
                MenuPlayer[iClient].iTargetIndex = GetPlayerIndex(sInfo);
                DrawPlayerSettingsMenu(iClient);
            }
        }
        case MenuAction_Cancel: { if (iItem == MenuCancel_ExitBack) { DrawWarnMainMenu(iClient); } }
        case MenuAction_End: { 
            
            delete menu; 
        }
    }
    return 0;
}
public void DrawPlayerSettingsMenu(int iClient) {
    Menu menu = new Menu(PlayerSettingsMenuHandle);
    char sMenuText[100];
    char sTargetName[MAX_NAME_LENGTH];
    if (StrEqual(MenuPlayer[iClient].sTargetName, "[[NOTFOUND]]", false)) {
        char sQuery[255];
        Format(sQuery, sizeof(sQuery), "SELECT name FROM sakaWarn WHERE steamid ='%s';", MenuPlayer[iClient].sSteamId);
        DBResultSet rsQuery = SQL_Query(DB, sQuery);
        if (rsQuery == null) {
            char sError[255];
            SQL_GetError(DB, sError, sizeof(sError));
            sTargetName = "(SQL ERROR)";
            PrintToServer("[sakaWARN] DrawAllTimePlayersMenu() failed to query (error: %s)", sError);
        } else {
            SQL_FetchRow(rsQuery);
            SQL_FetchString(rsQuery, 0, sTargetName, sizeof(sTargetName));
            MenuPlayer[iClient].sTargetName = sTargetName;
        }
    } else {
        sTargetName = MenuPlayer[iClient].sTargetName;
    }
    Format(sMenuText, sizeof(sMenuText), "Warn Settings of %s", sTargetName);
    menu.SetTitle(sMenuText);
    Format(sMenuText, sizeof(sMenuText), "Player Online: %s", (MenuPlayer[iClient].iTargetIndex == -1 ? "No" : "Yes"));
    menu.AddItem("0", sMenuText, ITEMDRAW_DISABLED);
    menu.AddItem("1", "Add Warning");
    menu.AddItem("2", "List All Warnings");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
    MenuPlayer[iClient].bInMenu = true;
}
public int PlayerSettingsMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: { 
            
            switch (iItem) {
                case 1: { 
                    MenuPlayer[iClient].bSayHook = true; 
                    MenuPlayer[iClient].fSayHookTime = GetGameTime();  
                    MenuPlayer[iClient].iSayHookType = 1; 
                    CPrintToChat(iClient, "%t", "ClientSayHookInfo");
                    CPrintToChat(iClient, "%t", "ClientSayHookInfo2");
                }
                case 2: {
                    if (!UserHasWarns(MenuPlayer[iClient].sSteamId)) {
                        CPrintToChat(iClient, "%t", "UserHasNoWarns");
                        return 0;
                    }
                    DrawPlayerWarnsMenu(iClient);
                }
            }
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack)  {
                if (MenuPlayer[iClient].iTargetIndex == -1) {
                    DrawAllTimePlayersMenu(iClient);
                } else {
                    DrawOnlinePlayersMenu(iClient);
                }
            }
        }
        case MenuAction_End: {
            
            delete menu;
        }
    }
    return 0;
}
public void DrawPlayerWarnsMenu(int iClient) {
    Menu menu = new Menu(PlayerWarnsMenuHandle);
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaWarn WHERE steamid ='%s' ORDER BY id;", MenuPlayer[iClient].sSteamId);
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaWARN] DrawPlayerWarnsMenu() failed to query (error: %s)", MenuPlayer[iClient].sSteamId, sError);
    } else {
        char sTargetName[MAX_NAME_LENGTH];
        if (MenuPlayer[iClient].iTargetIndex == -1) {
            sTargetName = GetPlayerNameFromDB(MenuPlayer[iClient].sSteamId);
        } else {
            GetClientName(MenuPlayer[iClient].iTargetIndex, sTargetName, sizeof(sTargetName));
        }
        char sMenuTitle[100];
        Format(sMenuTitle, sizeof(sMenuTitle), "Warns of %s", sTargetName);
        menu.SetTitle(sMenuTitle);
        char sMenuText[100];
        while(SQL_FetchRow(rsQuery)) {
            int iWarnId = SQL_FetchInt(rsQuery, 0);
            char sWarnId[16];
            Format(sWarnId, sizeof(sWarnId), "%i", iWarnId);
            Format(sMenuText, sizeof(sMenuText), "#%i", iWarnId);
            menu.AddItem(sWarnId, sMenuText);
        }
    }
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
    MenuPlayer[iClient].bInMenu = true;
}
public int PlayerWarnsMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            char sInfo[32];
            bool bFound = menu.GetItem(iItem, sInfo, sizeof(sInfo));
            if (bFound) {
                MenuPlayer[iClient].iWarnId = StringToInt(sInfo);
                DrawWarnMenu(iClient);
            }
        }
        case MenuAction_Cancel: { 
            if (iItem == MenuCancel_ExitBack) { 
                DrawPlayerSettingsMenu(iClient); 
            } 
        }
        case MenuAction_End: {   delete menu; }
    }
    return 0;
}
public void DrawWarnMenu(int iClient) {
    Menu menu = new Menu(WarnMenuHandle);
    int iWarnId = MenuPlayer[iClient].iWarnId;
    char sMenuTitle[64];
    Format(sMenuTitle, sizeof(sMenuTitle), "Warn Information for #%i", iWarnId);
    menu.SetTitle(sMenuTitle);
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaWarn WHERE id = %i;", iWarnId);
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        delete menu;
        PrintToServer("[sakaWARN] DrawWarnMenu(%i) failed to query (error: %s)", iWarnId, sError);
    } else { 
        SQL_FetchRow(rsQuery);
        char sReason[100];
        SQL_FetchString(rsQuery, 3, sReason, sizeof(sReason));
        char sExecutorId[100];
        SQL_FetchString(rsQuery, 4, sExecutorId, sizeof(sExecutorId));
        char sExecutorName[100];
        SQL_FetchString(rsQuery, 5, sExecutorName, sizeof(sExecutorName));
        char sDate[64];
        FormatTime(sDate, sizeof(sDate), "%x", SQL_FetchInt(rsQuery, 6));
        menu.AddItem("0", "Steam ID:", ITEMDRAW_DISABLED);
        menu.AddItem("1", MenuPlayer[iClient].sSteamId, ITEMDRAW_DISABLED);
        menu.AddItem("2", "Player Name:", ITEMDRAW_DISABLED);
        menu.AddItem("3", MenuPlayer[iClient].sTargetName, ITEMDRAW_DISABLED);
        menu.AddItem("4", "Reason:", ITEMDRAW_DISABLED);
        menu.AddItem("5", sReason, ITEMDRAW_DISABLED);
        menu.AddItem("6", "", ITEMDRAW_SPACER);
        menu.AddItem("7", "Executor Steam ID:", ITEMDRAW_DISABLED);
        menu.AddItem("8", sExecutorId, ITEMDRAW_DISABLED);
        menu.AddItem("9", "Executor Name:", ITEMDRAW_DISABLED);
        menu.AddItem("10", sExecutorName, ITEMDRAW_DISABLED);
        menu.AddItem("11", "Time Stamp:", ITEMDRAW_DISABLED);
        menu.AddItem("12", sDate, ITEMDRAW_DISABLED);
        menu.AddItem("13", "Delete Warn?");
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
    MenuPlayer[iClient].bInMenu = true;
}
public int WarnMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            switch(iItem) {
                case 13: {
                    DrawDeleteWarnMenu(iClient);
                }
            }
        }
        case MenuAction_Cancel: { 
            if (iItem == MenuCancel_ExitBack) { 
                DrawPlayerWarnsMenu(iClient); 
            }
        }
        case MenuAction_End: {   delete menu; }
    }
    return 0;
}
public void DrawDeleteWarnMenu(int iClient) {
    Menu menu = new Menu(DeleteWarnMenuHandle);
    char sMenuTitle[64];
    int iWarnId = MenuPlayer[iClient].iWarnId;
    Format(sMenuTitle, sizeof(sMenuTitle), "Delete Warn #%i", iWarnId);
    menu.SetTitle(sMenuTitle);
    menu.AddItem("yes", "Yes");
    menu.AddItem("no", "No");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
    MenuPlayer[iClient].bInMenu = true;
}
public int DeleteWarnMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            int iWarnId = MenuPlayer[iClient].iWarnId;
            switch (iItem) {
                case 0: {  
                    DeleteWarn(iWarnId);
                    CPrintToChat(iClient, "%t", "Menu_DeleteWarn_Success", iWarnId);
                }
                case 1: {
                     CPrintToChat(iClient, "%t", "Menu_DeleteWarn_Aborted", iWarnId);
                }
            }
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) {
                DrawWarnMenu(iClient); 
            }
        }
        case MenuAction_End: {   delete menu; }
    }
    return 0;
}
public Action AddWarnCommand(int iClient, int iArgs) {
    if (iArgs == 1) {
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
                MenuPlayer[iClient].sSteamId = sSteamId;
                /* setting command target to -1 if no online player was found */
                iTargetList[0] = GetPlayerIndex(sSteamId);
                
            } else if (IsEntityConnectedClient(iBackupTarget) && !IsFakeClient(iBackupTarget))  {
                /* client index as target given -> setting command target to client index */
                iTargetList[0] = iBackupTarget;
            } else {
                /* no matching client index / client id / client name or steamid found -> abort */
                CPrintToChat(iClient, "%t", "Command_AddWarn_NoUserFound");
                return Plugin_Handled;
            } 
        }
        /* if target count is over 1: abort */
        if (iTargetCount > 1) {
            CPrintToChat(iClient, "%t", "Command_AddWarn_NoMultipleTargets");
            return Plugin_Handled;
        }
        /* if target index is equal to client index: abort */
        if (iTargetList[0] == iClient) {
            CPrintToChat(iClient, "%t", "Command_AddWarn_NoWarnYourself");
            return Plugin_Handled;
        }
        MenuPlayer[iClient].bSayHook = true;
        MenuPlayer[iClient].fSayHookTime = GetGameTime();
        MenuPlayer[iClient].iSayHookType = 1;
        MenuPlayer[iClient].iTargetIndex = iTargetList[0];
        CPrintToChat(iClient, "%t", "ClientSayHookInfo");
        CPrintToChat(iClient, "%t", "ClientSayHookInfo2");
    } else {
        CPrintToChat(iClient, "%t", "Command_AddWarn_Usage");
    }
    return Plugin_Handled;
}
public Action ListWarnsCommand(int iClient, int iArgs) {
    if (iArgs == 1) {
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
                MenuPlayer[iClient].sSteamId = sSteamId;
                /* setting command target to -1 if no online player was found */
                iTargetList[0] = GetPlayerIndex(sSteamId);      
                if (iTargetList[0] == -1) {
                    
                }
            } else if (IsEntityConnectedClient(iBackupTarget) && !IsFakeClient(iBackupTarget))  {
                /* client index as target given -> setting command target to client index */
                iTargetList[0] = iBackupTarget;
            } else {
                /* no matching client index / client id / client name or steamid found -> abort */
                CPrintToChat(iClient, "%t", "Command_ListWarns_NoUserFound");
                return Plugin_Handled;
            } 
        }
        /* if target count is over 1: abort */
        if (iTargetCount > 1) {
            CPrintToChat(iClient, "%t", "Command_ListWarns_NoMultipleTargets");
            return Plugin_Handled;
        }
        MenuPlayer[iClient].iTargetIndex = iTargetList[0];
        if (MenuPlayer[iClient].iTargetIndex != -1) {
                MenuPlayer[iClient].sSteamId = GetSteamId(MenuPlayer[iClient].iTargetIndex);
        }
        if (!UserHasWarns(MenuPlayer[iClient].sSteamId)) {
            CPrintToChat(iClient, "%t", "UserHasNoWarns");
            return Plugin_Handled;
        }
        DrawPlayerWarnsMenu(iClient);
    } else {
        CPrintToChat(iClient, "%t", "Command_ListWarns_Usage");
    }
    return Plugin_Handled;
}
stock int GetTotalWarns() {
	int iCount = -1;
	char sQuery[48] = "SELECT * FROM sakaWarn;";
	DBResultSet rsQuery = SQL_Query(DB, sQuery, sizeof(sQuery));
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaWARN] GetTotalWarns() failed to query (error: %s)", sError);
	} else {
		iCount = SQL_GetRowCount(rsQuery);
	}
	return iCount;
}
stock bool IsEntityConnectedClient(int iEntity) {
	return 0 < iEntity <= MaxClients && IsClientInGame(iEntity);
}
stock char[] GetSteamId(int iClient) {
	char sSteamId[32];
	if (IsClientConnected(iClient) && !IsFakeClient(iClient)) {
		GetClientAuthId(iClient, AuthId_Steam2, sSteamId, sizeof(sSteamId), true);
	}
	return sSteamId;
}
stock char[] GetOnlineName(char[] sSteamId) {
    char sName[MAX_NAME_LENGTH];
    for (int iClient = 0; iClient <= MAXPLAYERS; iClient++) {
        if (IsEntityConnectedClient(iClient) && !IsFakeClient(iClient)) {
            if (StrEqual(GetSteamId(iClient), sSteamId, true)) {
                GetClientName(iClient, sName, sizeof(sName));
                return sName;
            }
        }
    }
    return sName;
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
public void DeleteWarn(int iWarnId) {
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "DELETE FROM sakaWarn WHERE id = %i;", iWarnId);
    if (!SQL_FastQuery(DB, sQuery)){
    	char sError[255]; 
        SQL_GetError(DB, sError, sizeof(sError)); 
        PrintToServer("[sakaWARN] DeleteWarn() failed to query (error: %s)", sError);
	}
}
public bool UserHasWarns(char[] sSteamId) {
    char sQuery[255]; 
    Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaWarn WHERE steamid ='%s';", sSteamId); 
    DBResultSet rsQuery = SQL_Query(DB, sQuery); 
    if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaWARN] UserHasWarns() failed to query (error: %s)", sError);
		return false;
	} else {
		return SQL_GetRowCount(rsQuery) > 0;
	}
}
public void AddWarnToUser(int iTarget, int iExecutor, bool bSendTargetMessage, bool bSendAnonymous, char[] sReason, int iWarnId) {
    char sTargetSteamId[64];
    char sTargetName[MAX_NAME_LENGTH];
    /* retrieving data from online user if target index is not -1 */
    if (iTarget != -1) {
        GetClientName(iTarget, sTargetName, sizeof(sTargetName));
        sTargetSteamId = GetSteamId(iTarget);
    } else {
        sTargetSteamId = MenuPlayer[iExecutor].sSteamId;
        sTargetName = MenuPlayer[iExecutor].sTargetName;
    }
    char sExecutorSteamId[64];
    sExecutorSteamId = GetSteamId(iExecutor);
    char sExecutorName[MAX_NAME_LENGTH];
    GetClientName(iExecutor, sExecutorName, sizeof(sExecutorName));
    /* Sending only a message if: --nm arg is not given, target index is not -1 */
    if (bSendTargetMessage && iTarget != -1) {
        CPrintToChat(iTarget, "%t", "PlayerReceivedWarn", (bSendAnonymous ? "ADMIN" : sExecutorName));
        CPrintToChat(iTarget, "%t", "PlayerReceivedWarnReason", sReason);
    }
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "INSERT INTO sakaWarn (id,steamid,name,reason,executorid,executorname,timeexecuted) VALUES ('%i', '%s', '%s', '%s', '%s', '%s', '%i');", iWarnId, sTargetSteamId, sTargetName, sReason, sExecutorSteamId, sExecutorName, GetTime());
    if (!SQL_FastQuery(DB, sQuery)){
    	char sError[255]; 
        SQL_GetError(DB, sError, sizeof(sError)); 
        PrintToServer("[sakaWARN] AddWarnToUser() failed to query (error: %s)", sError);
	}
}
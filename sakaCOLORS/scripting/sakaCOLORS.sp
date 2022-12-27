#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <chat-processor>
#include <dbi>




#define PLUGIN_VERSION 		"1.0"
#define PLUGIN_NAME 		"sakaCOLORS"
#define PLUGIN_AUTHOR 		"ѕαĸα"
#define PLUGIN_DESCRIPTION  "Chnge Thirdperson and Firstperson"
#define PLUGIN_URL 			"https://tf2.l03.dev/"
#define SQL_QUERY_CREATE "CREATE TABLE IF NOT EXISTS sakaColors_Clients (steamid VARCHAR(64), tagColor VARCHAR(32), chatColor VARCHAR(32), nameColor VARCHAR(32), tag VARCHAR(64), groupName VARCHAR(64), useGroupTag INT, useGroupTagColor INT, useGroupNameColor INT, useGroupChatColor INT);"

Handle DB = INVALID_HANDLE;
 

public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

enum struct PlayerInfo {
    char sTag[64];
    char sTagColor[32];
    char sNameColor[32];
    char sChatColor[32];
    char sGroup[64];
    bool bUseGroupTag;
    bool bUseGroupTagColor;
    bool bUseGroupNameColor;
    bool bUseGroupChatColor;
    /**
     * Menu Settings Option
     */
    int iCurrentSettingOption;
}

enum struct GroupInfo {
    char sTag[64];
    char sTagColor[32];
    char sNameColor[32];
    char sChatColor[32];
}


PlayerInfo CI[MAXPLAYERS];
KeyValues kvConfig;
StringMap mGroups;

public void OnPluginStart() {
    LoadConfig();
    TestConfig();
    PrintToServer("[sakaCOLORS] Enabling Plugin (Version %s)", PLUGIN_VERSION);
    InitDatabase(true);
    LoadAllPlayersFromDB();
    RegConsoleCmd("sm_scc", MainCommand);
    HookEvent("teamplay_round_win", RoundEndEvent, EventHookMode_PostNoCopy);
}
public void OnPluginEnd() {
    LoadAllPlayersToDB();
    InitDatabase(false);
    PrintToServer("[sakaCOLORS] Disabling Plugin");
   /* GroupInfo group;
    group.sFlag = "d";
    StringMap smap = new StringMap();
    smap.SetValue("admin", );    */
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrMax) {
    return APLRes_Success;
}
public Action RoundEndEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	LoadAllPlayersToDB();
	return Plugin_Handled;
}

public void LoadConfig() {
    char sPath[64];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/sakacolors.cfg");
    kvConfig = new KeyValues("sakacolors");
    mGroups = new StringMap();
    if (!kvConfig.ImportFromFile(sPath)) {
        SetFailState("Config file missing");
    }

    if (kvConfig.JumpToKey("groups")) {
        kvConfig.GotoFirstSubKey();
        do {
            char sGroupName[64];
            kvConfig.GetSectionName(sGroupName, sizeof(sGroupName));
            StringMap sData = new StringMap();
            char sBuffer[255];
            kvConfig.GetString("tag", sBuffer, sizeof(sBuffer));
            sData.SetString("tag", sBuffer);
            kvConfig.GetString("tagcolor", sBuffer, sizeof(sBuffer));
            sData.SetString("tagcolor", sBuffer);
            kvConfig.GetString("namecolor", sBuffer, sizeof(sBuffer));
            sData.SetString("namecolor", sBuffer);
            kvConfig.GetString("chatcolor", sBuffer, sizeof(sBuffer));
            sData.SetString("chatcolor", sBuffer);
            mGroups.SetValue(sGroupName, sData);
        } while (kvConfig.GotoNextKey());
    }
}

public void TestConfig() {
    GroupInfo owner;
    owner = GetGroupInfo("owner");
    PrintToServer("[COLORS] Owner-Tag: %s", owner.sTag);
    PrintToServer("[COLORS] Owner-TagColor: %s", owner.sTagColor);
    PrintToServer("[COLORS] Owner-NameColor: %s", owner.sNameColor);
    PrintToServer("[COLORS] Owner-ChatColor: %s", owner.sChatColor);
}

public void OnClientPostAdminCheck(int iClient) {
    if (IsClientConnected(iClient) && !IsFakeClient(iClient)) {
        if (PlayerExists(iClient)) {
            LoadPlayerFromDB(iClient);
        } else {
            CreatePlayer(iClient);
        }
    }   
}
public void OnClientDisconnect(int iClient) {
    if (!IsFakeClient(iClient) && PlayerExists(iClient)) {
        LoadPlayerToDB(iClient);
    }  
}

public void InitDatabase(bool bConnect) {
	char sError[255];
	if (bConnect) {
        DB = SQL_Connect("sakacolors", true, sError, sizeof(sError));
        if (DB == INVALID_HANDLE) {
            PrintToServer("[sakaCOLORS] Could not connect to database: %s", sError);
            delete DB;
        }
        PrintToServer("[sakaCOLORS] Connecting to database...");
        if (!SQL_FastQuery(DB, SQL_QUERY_CREATE)) {
            SQL_GetError(DB, sError, sizeof(sError));
            PrintToServer("[sakaCOLORS] Failed to create client table: %s", sError);
        }
	} else {
		delete DB;
	}
}


public Action MainCommand(int iClient, int iArgs) {
    /**
     * load data from database, save data to database on disconnect etc... (caching)
     */
    /**
     * check if color exists with name comparison and regex check
     */
    /**
     * add tag with onsaytext2 like on warn system interactive
     */
    if (iArgs == 0) {
        DrawMainMenu(iClient);
    } else if (iArgs == 2) {
        char sType[32];
        char sColor[32];
        GetCmdArg(1, sType, sizeof(sType));
        GetCmdArg(2, sColor, sizeof(sColor));
        if (StrEqual(sType, "chatcolor")) {
            Format(sColor, sizeof(sColor), "{%s}", sColor);
            if (ColorCodeFound(sColor)) {
                CI[iClient].sChatColor = sColor;
                CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Changed Chat Color to: %sExample", sColor);
            } else {
                CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {red}Could not found Color: %s", sColor);
            }
        } else if (StrEqual(sType, "namecolor")) {
            Format(sColor, sizeof(sColor), "{%s}", sColor);
            if (ColorCodeFound(sColor)) {
                CI[iClient].sNameColor = sColor;
                CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Changed Name Color to: %sExample", sColor);
            } else {
                CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {red}Could not found Color: %s", sColor);
            }
        } else if (StrEqual(sType, "tagcolor")) {
            Format(sColor, sizeof(sColor), "{%s}", sColor);
            if (ColorCodeFound(sColor)) {
                CI[iClient].sTagColor = sColor;
                CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Changed Tag Color to: %sExample", sColor);
            } else {
                CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {red}Could not found Color: %s", sColor);
            }
        } else if (StrEqual(sType, "tag")) {
            CI[iClient].sTag = sColor;
            CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Changed Tag to: %s", sColor);
        } else {
            CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {red}Use /scc <name|chat|tag> <color>");
        }
    } else {
        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {red}Use /scc <name|chat|tag> <color>");
    }
    return Plugin_Handled;
}


public void DrawMainMenu(int iClient) {
    Menu menu = new Menu(MainMenuHandle);
    menu.SetTitle("Custom Colors Main Menu");
    menu.AddItem("0", "Your Colors");
    menu.AddItem("1", "Available Groups");
    menu.AddItem("2", "Available Tags");
    menu.AddItem("3", "Settings");
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int MainMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            switch (iItem) {
                case 0: {
                    delete menu;
                    CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Current Group: %s", CI[iClient].sGroup);
                    if (PlayerHasTag(iClient)) {
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Current Tag: %s", CI[iClient].sTag);
                    } 
                    if (PlayerHasCustomTagColor(iClient)) {
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Current Tag Color: %sExample", CI[iClient].sTagColor);
                    }
                    if (PlayerHasCustomChatColor(iClient)) {
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Current Chat Color: %sExample", CI[iClient].sChatColor);
                    }
                    if (PlayerHasCustomNameColor(iClient)) {
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}Current Name Color: %sExample", CI[iClient].sNameColor);
                    }
                }
                case 3: {
                    DrawSettingsMenu(iClient);
                }
            }
        }
    }
    return 0;
}

public void DrawSettingsMenu(int iClient) {
    Menu menu = new Menu(SettingsMenuHandle);
    menu.SetTitle("Custom Colors Settings");
    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Use Group Tag: %s", CI[iClient].bUseGroupTag ? "Yes" : "No");
    menu.AddItem("0", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Use Group TagColor: %s", CI[iClient].bUseGroupTagColor ? "Yes" : "No");
    menu.AddItem("1", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Use Group NameColor: %s", CI[iClient].bUseGroupNameColor ? "Yes" : "No");
    menu.AddItem("2", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Use Group ChatColor: %s", CI[iClient].bUseGroupChatColor ? "Yes" : "No");
    menu.AddItem("3", sBuffer);
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}
public int SettingsMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            switch (iItem) {
                case 0: { 
                        CI[iClient].bUseGroupTag = !CI[iClient].bUseGroupTag; 
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You %s {default}the {dodgerblue}Use Group Tag {default}Option.", CI[iClient].bUseGroupTag ? "{green}Enabled" : "{red}Disabled"); 
                    }
                case 1: { 
                        CI[iClient].bUseGroupTagColor = !CI[iClient].bUseGroupTagColor; 
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group TagColor {default}Option.", CI[iClient].bUseGroupTagColor ? "{green}Enabled" : "{red}Disabled"); 
                    }
                case 2: {
                        CI[iClient].bUseGroupNameColor = !CI[iClient].bUseGroupNameColor; 
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group NameColor {default}Option.", CI[iClient].bUseGroupNameColor ? "{green}Enabled" : "{red}Disabled"); 
                    }
                case 3: { 
                        CI[iClient].bUseGroupChatColor = !CI[iClient].bUseGroupChatColor; 
                        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group ChatColor {default}Option.", CI[iClient].bUseGroupChatColor ? "{green}Enabled" : "{red}Disabled");
                    }
            }
            delete menu;
            DrawSettingsMenu(iClient);
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) { DrawMainMenu(iClient); }
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}
public void DrawChangeSettingMenu(int iClient, int iSetting) {
    Menu menu = new Menu(ChangeSettingMenuHandle);
    menu.SetTitle("Change Custom Colors Settings");
    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Use Group Tag: %s", CI[iClient].bUseGroupTag ? "Yes" : "No");
    menu.AddItem("0", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Use Group TagColor: %s", CI[iClient].bUseGroupTagColor ? "Yes" : "No");
    menu.AddItem("1", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Use Group NameColor: %s", CI[iClient].bUseGroupNameColor ? "Yes" : "No");
    menu.AddItem("2", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Use Group ChatColor: %s", CI[iClient].bUseGroupChatColor ? "Yes" : "No");
    menu.AddItem("3", sBuffer);
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}
public int ChangeSettingMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
    switch (action) {
        case MenuAction_Select: {
            if (iItem == 0) {
                switch (CI[iClient].iCurrentSettingOption) {
                    case 0: { CI[iClient].bUseGroupTag = true; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group Tag {default}Option."); }
                    case 1: { CI[iClient].bUseGroupTagColor = true; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group TagColor {default}Option."); }
                    case 2: { CI[iClient].bUseGroupNameColor = true; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group NameColor {default}Option."); }
                    case 3: { CI[iClient].bUseGroupTag = true; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {green}Enabled {default}the {dodgerblue}Use Group ChatColor {default}Option."); }
                }
            } else if (iItem == 1) {
                switch (CI[iClient].iCurrentSettingOption) {
                    case 0: { CI[iClient].bUseGroupTag = false; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {red}Disabled {default}the {dodgerblue}Use Group Tag {default}Option."); }
                    case 1: { CI[iClient].bUseGroupTagColor = false; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {red}Disabled {default}the {dodgerblue}Use Group TagColor {default}Option."); }
                    case 2: { CI[iClient].bUseGroupNameColor = false; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {red}Disabled {default}the {dodgerblue}Use Group NameColor {default}Option."); }
                    case 3: { CI[iClient].bUseGroupTag = false; CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {default}You {red}Disabled {default}the {dodgerblue}Use Group ChatColor {default}Option."); }
                }
            }
        }
        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) { DrawSettingsMenu(iClient); }
        }
        case MenuAction_End: {
            delete menu;
        }
    }
    return 0;
}

stock bool ColorCodeFound(char[] sInput) {
    bool bFound = false;

    int iMaxLen = MAX_BUFFER_LENGTH;
    /**
     * Normal Copy of sInput in LOWER CASE
     */
    char sValue[32];
    strcopy(sValue, iMaxLen, sInput);
    CStrToLower(sValue);
    /**
     * Copy of sValue WITHOUT BRACKETS
     */
    char sBrackets[32];
    strcopy(sBrackets, iMaxLen, sValue);
    ReplaceString(sBrackets, sizeof(sBrackets), "{", "");
    ReplaceString(sBrackets, sizeof(sBrackets), "}", "");
    /**
     * Converted Value of TAG
     */
    char sOutput[32];
    strcopy(sOutput, iMaxLen, sBrackets);

    Regex regex = new Regex("{[#a-zA-Z0-9]+}");
    StringMap colormap = CGetTrie();
    if (regex.Match(sInput) <= 0) return false;
    if (sBrackets[0] == '#') {
        if (strlen(sBrackets) == 7 || strlen(sBrackets) == 9) {
            bFound = true;
        }
    } else {
        if (colormap.GetString(sBrackets, sOutput, sizeof(sOutput))) {
            bFound = true;
        }
    }
    return bFound;
}
stock bool PlayerHasTag(int iClient) {
    return strlen(CI[iClient].sTag) >= 2; 
}
stock bool PlayerHasCustomTagColor(int iClient) {
    return strlen(CI[iClient].sTagColor) >= 4; 
}
stock bool PlayerHasCustomChatColor(int iClient) {
    return strlen(CI[iClient].sChatColor) >= 4;
}
stock bool PlayerHasCustomNameColor(int iClient) {
    return strlen(CI[iClient].sNameColor) >= 4;
}
stock bool IsEntityConnectedClient(int iEntity) {
	return 0 < iEntity <= MaxClients && IsClientInGame(iEntity);
}
stock char[] GetSteamId(int iClient) {
	char sSteamId[32];
	if (IsEntityConnectedClient(iClient)) {
		GetClientAuthId(iClient, AuthId_Steam2, sSteamId, sizeof(sSteamId), true);
	}
	return sSteamId;
}
/*
stock bool GroupExists(char[] sGroupName) {
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT steamid FROM sakaColors_Groups WHERE name ='%s';", sGroupName);
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaCOLORS] GroupExists(Error) Failed to Query (error: %s)", sError);
		return false;
	} else {
		return SQL_GetRowCount(rsQuery) > 0;
	}
}
stock GroupInfo GetGroup(char[] sGroupName) {
    GroupInfo group;
    group.Init();
    char sQuery[500];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaColors_Groups WHERE name='%s';", sGroupName);
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaCOLORS] GetGroup(Error) Failed to Query (error: %s)", sError);
    } else {
        SQL_FetchRow(rsQuery);
        SQL_FetchString(rsQuery, 1, group.sTagColor, sizeof(group.sTagColor));
        SQL_FetchString(rsQuery, 2, group.sChatColor, sizeof(group.sChatColor));
        SQL_FetchString(rsQuery, 3, group.sNameColor, sizeof(group.sNameColor));
        SQL_FetchString(rsQuery, 4, group.sTag, sizeof(group.sTag));
        SQL_FetchString(rsQuery, 5, group.sFlag, sizeof(group.sFlag));
        PrintToServer("[sakaCOLORS] Loaded Group from Database: %s", sGroupName);
    }
    return group;
}

public void CreateGroup(char[] sGroupName, char[] sTag, char[] sTagColor, char[] sNameColor, char[] sChatColor, char[] sFlag) {
    
}*/
public Action CP_OnChatMessage(int &iAuthor, ArrayList alReciipiients, char[] sFlag, char[] sName, char[] sMessage, bool& bProcessColors, bool& bRemoveColors) {
    GroupInfo group;
    PlayerInfo player;
    player = CI[iAuthor];
    group = GetGroupInfo(player.sGroup);
    char sNameColor[32];  
    sNameColor = ((player.bUseGroupNameColor && strlen(group.sNameColor) >= 4) ? group.sNameColor : (strlen(player.sNameColor) >= 4 ? player.sNameColor : ""));
    if (strlen(sNameColor) >= 4) {
         Format(sName, MAXLENGTH_NAME, "%s%s", sNameColor, sName);
    }
    char sChatColor[32];    
    sChatColor = ((player.bUseGroupChatColor && strlen(group.sChatColor) >= 4) ? group.sChatColor : (strlen(player.sChatColor) >= 4 ? player.sChatColor : ""));
    if (strlen(sChatColor) >= 4) {
        Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", sChatColor, sMessage);
    }
    char sTagColor[32];
    sTagColor = ((player.bUseGroupTagColor && strlen(group.sTagColor) >= 4) ? group.sTagColor : (strlen(player.sTagColor) >= 4 ? player.sTagColor : ""));
    /**
     * If player uses Group Tag & Group Tag Length equals 1 or more -> Continue
     */
    if (player.bUseGroupTag && strlen(group.sTag) >= 1 ) {
        Format(sName, MAXLENGTH_NAME, "%s%s {teamcolor}%s", (strlen(sTagColor) >= 4 ? sTagColor : ""), group.sTag, sName);
    } else if (strlen(player.sTag) >= 1) {
        /**
         * If player used own Custom Tag & Custom Tag Length equals 1 or more -> Continue
         */
        Format(sName, MAXLENGTH_NAME, "%s%s {teamcolor}%s", (strlen(sTagColor) >= 4 ? sTagColor : ""), player.sTag, sName);
    }
    return Plugin_Changed;
}



public void LoadAllPlayersFromDB() {
    for (int i = 1; i < MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            if (PlayerExists(i)) {
                LoadPlayerFromDB(i);
            } else {
                CreatePlayer(i);
            }
        }
    }
}
public void LoadAllPlayersToDB() {
    for (int i = 1; i < MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            if (PlayerExists(i)) {
                LoadPlayerToDB(i);
            }
        }
    }
}
public void LoadPlayerFromDB(int iClient) {
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaColors_Clients WHERE steamid='%s';", GetSteamId(iClient));
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaCOLORS] LoadPlayerFromDB() Failed to query (error: %s)", sError);
	} else {
        SQL_FetchRow(rsQuery);
        PlayerInfo p;
        SQL_FetchString(rsQuery, 1, p.sTagColor, sizeof(p.sTagColor));
        SQL_FetchString(rsQuery, 2, p.sChatColor, sizeof(p.sChatColor));
        SQL_FetchString(rsQuery, 3, p.sNameColor, sizeof(p.sNameColor));
        SQL_FetchString(rsQuery, 4, p.sTag, sizeof(p.sTag));
        SQL_FetchString(rsQuery, 5, p.sGroup, sizeof(p.sGroup));
        p.bUseGroupTag = SQL_FetchInt(rsQuery, 6) == 1 ? true : false;
        p.bUseGroupTagColor = SQL_FetchInt(rsQuery, 7) == 1 ? true : false;
        p.bUseGroupNameColor = SQL_FetchInt(rsQuery, 8) == 1 ? true : false;
        p.bUseGroupChatColor = SQL_FetchInt(rsQuery, 9) == 1 ? true : false;
        CI[iClient] = p;
        PrintToServer("[sakaCOLORS] LoadPlayerFromDB() %N", iClient);
    }
}
public void LoadPlayerToDB(int iClient) {
    PrintToServer("[sakaCOLORS] LoadPlayerToDB() %N", iClient);
    int iUseGroupTag = CI[iClient].bUseGroupTag ? 1 : 0;
    int iUseGroupTagColor = CI[iClient].bUseGroupTagColor ? 1 : 0;
    int iUseGroupNameColor = CI[iClient].bUseGroupNameColor ? 1 : 0;
    int iUseGroupChatColor = CI[iClient].bUseGroupChatColor ? 1 : 0;
    char sQuery[500];
    Format(sQuery, sizeof(sQuery), "UPDATE sakaColors_Clients SET tagColor='%s' ,chatColor='%s',nameColor='%s',tag='%s',groupName='%s',useGroupTag='%i',useGroupTagColor='%i',useGroupNameColor='%i',useGroupChatColor='%i' WHERE steamid='%s';", CI[iClient].sTagColor, CI[iClient].sChatColor, CI[iClient].sNameColor, CI[iClient].sTag, CI[iClient].sGroup, iUseGroupTag, iUseGroupTagColor, iUseGroupNameColor, iUseGroupChatColor, GetSteamId(iClient));
    if (!SQL_FastQuery(DB, sQuery)) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaCOLORS] Failed to update client table: %s", sError);
    }
}
public void CreatePlayer(int iClient) {
    char sQuery[255]; 
    Format(sQuery, sizeof(sQuery), "INSERT INTO sakaColors_Clients (steamid,tagColor,chatColor,nameColor,tag,groupName,useGroupTag,useGroupTagColor,useGroupNameColor,useGroupChatColor) VALUES ('%s','','','','','default','1','1','1','1');", GetSteamId(iClient));
    if (!SQL_FastQuery(DB, sQuery)) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaCOLORS] CreatePlayer() Failed to Query (error: %s)", sError);
    }
    PrintToServer("[sakaCOLORS] CreatePlayer() %N", iClient);
    CI[iClient].bUseGroupTag = true;
    CI[iClient].bUseGroupTagColor = true;
    CI[iClient].bUseGroupNameColor = true;
    CI[iClient].bUseGroupChatColor = true;
    CI[iClient].sChatColor = "";
    CI[iClient].sNameColor = "";
    CI[iClient].sTagColor = "";
    CI[iClient].sTag = "";
    CI[iClient].sGroup = "default";
}
stock bool PlayerExists(int iClient) {
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT steamid FROM sakaColors_Clients WHERE steamid ='%s';", GetSteamId(iClient));
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaCOLORS] PlayerExists() Failed to Query (error: %s)", sError);
		return false;
	} else {
		return SQL_GetRowCount(rsQuery) > 0;
	}
}
stock GroupInfo GetGroupInfo(char[] sGroupName) {
    GroupInfo group;
    StringMap sData;
    mGroups.GetValue(sGroupName, sData);
    sData.GetString("tag", group.sTag, sizeof(group.sTag));
    sData.GetString("namecolor", group.sNameColor, sizeof(group.sNameColor));
    sData.GetString("tagcolor", group.sTagColor, sizeof(group.sTagColor));
    sData.GetString("chatcolor", group.sChatColor, sizeof(group.sChatColor));
    return group;
}
stock bool GroupExists(char[] sGroupName) {
    return mGroups.ContainsKey(sGroupName);
}
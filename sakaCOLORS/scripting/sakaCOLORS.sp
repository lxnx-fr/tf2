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
#define SQL_QUERY_CREATE_CLIENTS "CREATE TABLE IF NOT EXISTS sakaColors_Clients (steamid VARCHAR(64), tagColor VARCHAR(32), chatColor VARCHAR(32), nameColor VARCHAR(32), tag VARCHAR(64), groupName VARCHAR(64), useGroupValues INT);"
#define SQL_QUERY_CREATE_GROUPS "CREATE TABLE IF NOT EXISTS sakaColors_Groups (name VARCHAR(64), tagColor VARCHAR(32), chatColor VARCHAR(32), nameColor VARCHAR(32), tag VARCHAR(64), flags VARCHAR(10));"

Handle DB = INVALID_HANDLE;
 

public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

enum struct ColorInfo {
    char sTag[64];
    char sTagColor[32];
    char sNameColor[32];
    char sChatColor[32];
    char sGroup[64];
    bool bUseGroupValues;

}

enum struct GroupInfo {
    char sTag[64];
    char sTagColor[32];
    char sNameColor[32];
    char sChatColor[32];
    char sFlag[32];
    void Init() {
       this.sTag = "";
       this.sNameColor = "";
       this.sFlag = "";
       this.sChatColor = "";
       this.sTagColor = "";
    }
}


ColorInfo CI[MAXPLAYERS];

public void OnPluginStart() {
    //LoadConfig();
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
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrMax) {
    return APLRes_Success;
}
public Action RoundEndEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	LoadAllPlayersToDB();
	return Plugin_Handled;
}
/*
public void LoadConfig() {
    char sPath[64];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/sakacolors.cfg");
    kvConfig = new KeyValues("sakacolors");
    if (!kvConfig.ImportFromFile(sPath)) {
        SetFailState("Config file missing");
    }

    if (kvConfig.JumpToKey("groups")) {
        kvConfig.GotoFirstSubKey();
        do {
            char sGroupName[64];
            kvConfig.GetSectionName(sGroupName, sizeof(sGroupName));
            char sTag[64];
            kvConfig.GetString("tag", sTag, 64);
            PrintToServer("[COLORS] Group Name: %s", sGroupName);
            PrintToServer("[COLORS] Group Tag: %s", sTag);
            
        } while (kvConfig.GotoNextKey());
       
    }
}*/

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
		//DB = SQL_ConnectCustom(DB_KEYVALUES, sError, sizeof(sError), false);
        if (DB == INVALID_HANDLE) {
            PrintToServer("[sakaCOLORS] Could not connect to database: %s", sError);
            delete DB;
        }
        PrintToServer("[sakaCOLORS] Connecting to database...");
        if (!SQL_FastQuery(DB, SQL_QUERY_CREATE_CLIENTS)) {
            SQL_GetError(DB, sError, sizeof(sError));
            PrintToServer("[sakaCOLORS] Failed to query (error: %s)", sError);
        }
        if (!SQL_FastQuery(DB, SQL_QUERY_CREATE_GROUPS)) {
            SQL_GetError(DB, sError, sizeof(sError));
            PrintToServer("[sakaCOLORS] Failed to query (error: %s)", sError);
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
        CPrintToChat(iClient, "{mediumpurple}sᴄᴄ {black}» {red} Use /scc <name|chat|tag> <color>");
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
    
}
public Action CP_OnChatMessage(int &iAuthor, ArrayList alReciipiients, char[] sFlag, char[] sName, char[] sMessage, bool& bProcessColors, bool& bRemoveColors) {
    if (PlayerHasCustomNameColor(iAuthor)) {
        Format(sName, MAXLENGTH_NAME, "%s%s", CI[iAuthor].sNameColor, sName);
    }
    if (PlayerHasCustomChatColor(iAuthor)) {
        Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", CI[iAuthor].sChatColor, sMessage);
    }
    if (PlayerHasTag(iAuthor)) {
        Format(sName, MAXLENGTH_NAME, "%s%s {teamcolor}%s", (PlayerHasCustomTagColor(iAuthor) ? CI[iAuthor].sTagColor : ""), CI[iAuthor].sTag, sName);
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
        char sTagColor[32];
        char sChatColor[32];
        char sNameColor[32];
        char sGroup[64];
        char sTag[64];
        SQL_FetchString(rsQuery, 1, sTagColor, sizeof(sTagColor));
        SQL_FetchString(rsQuery, 2, sChatColor, sizeof(sChatColor));
        SQL_FetchString(rsQuery, 3, sNameColor, sizeof(sNameColor));
        SQL_FetchString(rsQuery, 4, sTag, sizeof(sTag));
        SQL_FetchString(rsQuery, 5, sGroup, sizeof(sGroup));
        bool bUseGroupValues = SQL_FetchInt(rsQuery, 6) == 1 ? true : false;
        CI[iClient].bUseGroupValues = bUseGroupValues;
        CI[iClient].sTag = sTag;
        CI[iClient].sGroup = sGroup;
        CI[iClient].sChatColor = sChatColor;
        CI[iClient].sTagColor = sTagColor;
        CI[iClient].sNameColor = sNameColor;
        PrintToServer("[sakaCOLORS] LoadPlayerFromDB() %N", iClient);
    }
}
public void LoadPlayerToDB(int iClient) {
    PrintToServer("[sakaCOLORS] LoadPlayerToDB() %N", iClient);
    int iUseGroupValues = CI[iClient].bUseGroupValues ? 1 : 0;
    char sQuery[500];
    Format(sQuery, sizeof(sQuery), "UPDATE sakaColors_Clients SET tagColor='%s',chatColor='%s',nameColor='%s',tag='%s',groupName='%s',useGroupValues='%i' WHERE steamid='%s';", CI[iClient].sTagColor, CI[iClient].sChatColor, CI[iClient].sNameColor, CI[iClient].sTag,CI[iClient].sGroup, iUseGroupValues, GetSteamId(iClient));
    SQL_FastQuery(DB, sQuery);
}
public void CreatePlayer(int iClient) {
    char sQuery[255]; 
    Format(sQuery, sizeof(sQuery), "INSERT INTO sakaColors_Clients (steamid,tagColor,chatColor,nameColor,tag,groupName,useGroupValues) VALUES ('%s','','','','','default','1');", GetSteamId(iClient));
    if (!SQL_FastQuery(DB, sQuery)) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaCOLORS] CreatePlayer() Failed to Query (error: %s)", sError);
    }
    PrintToServer("[sakaCOLORS] CreatePlayer() %N", iClient);
    CI[iClient].bUseGroupValues = true;
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

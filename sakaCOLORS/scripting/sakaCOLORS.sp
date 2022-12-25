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
#define SQL_QUERY_CREATE 	"CREATE TABLE IF NOT EXISTS sakaColors (steamid VARCHAR(100), tagColor VARCHAR(100), chatColor VARCHAR(100), nameColor VARCHAR(100), tag VARCHAR(100), groupName VARCHAR(100), useGroupValues INT);"

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
}

ColorInfo CI[MAXPLAYERS];

public void OnPluginStart() {
    PrintToServer("[sakaCOLORS] Enabling Plugin (Version %s)", PLUGIN_VERSION);
    InitDatabase(true);
    RegConsoleCmd("sm_scc", MainCommand);
    HookEvent("teamplay_round_win", RoundEndEvent, EventHookMode_PostNoCopy);
    for (int i = 1; i < MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            LoadPlayer(i);
        }
    }
}

public void OnPluginEnd() {
    for (int i = 1; i < MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && PlayerExists(i)) {
            LoadPlayerToDB(i);
        }
    }
    InitDatabase(false);
    PrintToServer("[sakaCOLORS] Disabling Plugin");
}

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrMax) {
    return APLRes_Success;
}

public Action RoundEndEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
    for (int i = 1; i < MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && PlayerExists(i)) {
            LoadPlayerToDB(i);
        }
    }
    return Plugin_Continue;
}

public void OnClientConnected(int iClient) {
    if (!IsFakeClient(iClient)) {
        LoadPlayer(iClient);
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
	    	CloseHandle(DB);
		}
		PrintToServer("[sakaCOLORS] Connecting to database...");
		if (!SQL_FastQuery(DB, SQL_QUERY_CREATE)) {
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





public void LoadPlayer(int iClient) {
    if (PlayerExists(iClient)) {
        LoadPlayerFromDB(iClient);
    } else {
        CreatePlayer(iClient);
    }
}

public void LoadPlayerFromDB(int iClient) {
    PrintToServer("[sakaCOLORS] LoadPlayerFromDB(Start) %N", iClient);
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaColors WHERE steamid='%s';", GetSteamId(iClient));
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] LoadPlayerFromDB(Error) Failed to query (error: %s)", sError);
	} else {
        SQL_FetchRow(rsQuery);
        SQL_FetchString(rsQuery, 1, CI[iClient].sTagColor, sizeof(CI[].sTagColor));
        SQL_FetchString(rsQuery, 2, CI[iClient].sChatColor, sizeof(CI[].sChatColor));
        SQL_FetchString(rsQuery, 3, CI[iClient].sNameColor, sizeof(CI[].sNameColor));
        SQL_FetchString(rsQuery, 4, CI[iClient].sTag, sizeof(CI[].sTag));
        SQL_FetchString(rsQuery, 5, CI[iClient].sGroup, sizeof(CI[].sGroup));
        bool bUseGroupValues = SQL_FetchInt(rsQuery, 6) == 1 ? true : false;
        CI[iClient].bUseGroupValues = bUseGroupValues;
        PrintToServer("[sakaCOLORS] LoadPlayerFromDB(End) %N", iClient);
    }
}

public void LoadPlayerToDB(int iClient) {
    PrintToServer("[sakaCOLORS] LoadPlayerToDB() %N %i", iClient, iClient);
    char sQuery[500];
    char sTagColor[32];
    char sChatColor[32];
    char sNameColor[32];
    char sGroup[64];
    char sTag[64];
    strcopy(sTagColor, 32, CI[iClient].sTagColor);
    strcopy(sChatColor, 32, CI[iClient].sChatColor);
    strcopy(sNameColor, 32, CI[iClient].sNameColor);
    strcopy(sTag, 64, CI[iClient].sTag);
    strcopy(sGroup, 64, CI[iClient].sGroup);
    int iUseGroupValues = CI[iClient].bUseGroupValues ? 1 : 0;
    Format(sQuery, sizeof(sQuery), "UPDATE sakaColors SET tagColor='%s',chatColor='%s',nameColor='%s',tag='%s',groupName='%s',useGroupValues='%i' WHERE steamid='%s';", sTagColor, sChatColor, sNameColor, sTag, sGroup, iUseGroupValues, GetSteamId(iClient));
    SQL_FastQuery(DB, sQuery);
}

public void CreatePlayer(int iClient) {
    char sQuery[255]; 
    PrintToServer("[sakaCOLORS] CreatePlayer(Start): %N %i", iClient, iClient);
    Format(sQuery, sizeof(sQuery), "INSERT INTO sakaColors (steamid,tagColor,chatColor,nameColor,tag,groupName,useGroupValues) VALUES ('%s','','','','','default','1');", GetSteamId(iClient));
    if (!SQL_FastQuery(DB, sQuery)) {
        char sError[255];
        SQL_GetError(DB, sError, sizeof(sError));
        PrintToServer("[sakaCOLORS] CreatePlayer(Error) Failed to Query (error: %s)", sError);
    }
    PrintToServer("[sakaCOLORS] CreatePlayer(End): %N", iClient);
    CI[iClient].bUseGroupValues = true;
    CI[iClient].sChatColor = "";
    CI[iClient].sNameColor = "";
    CI[iClient].sTagColor = "";
    CI[iClient].sTag = "";
    CI[iClient].sGroup = "default";
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
stock bool PlayerExists(int iClient) {
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT steamid FROM sakaColors WHERE steamid ='%s';", GetSteamId(iClient));
    DBResultSet rsQuery = SQL_Query(DB, sQuery);
    if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaCOLORS] PlayerExists(Error) Failed to Query (error: %s)", sError);
		return false;
	} else {
		return SQL_GetRowCount(rsQuery) > 0;
	}
}


/* 
public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message) {
    char sNameColor[64];
    if (PlayerHasCustomNameColor(author)) {
        strcopy(sNameColor, 64, CI[author].sNameColor);
        CReplaceColorCodes(sNameColor, author);
        Format(name, MAXLENGTH_NAME, "%s%s", sNameColor, name);
    } else {
        sNameColor = "{teamcolor}";
        CReplaceColorCodes(sNameColor, author);
        Format(name, MAXLENGTH_NAME, "%s%s", sNameColor, name);
    }
    if (PlayerHasTag(author)) {    
        char sTag[64];
        strcopy(sTag, 64, CI[author].sTag);
        CReplaceColorCodes(sTag, author);
        Format(name, MAXLENGTH_NAME, "%s%s", sTag, name);
    }
    if (PlayerHasCustomChatColor(author)) {
        char sChatColor[64];
        strcopy(sChatColor, 64, CI[author].sChatColor);
        CReplaceColorCodes(sChatColor, author);
        Format(message, MAXLENGTH_MESSAGE, "%s%s", sChatColor, message);
    } else {
        Format(message, MAXLENGTH_MESSAGE, "\x01%s", message);
    }
   if (CheckForward(iAuthor, sMessage, CT_NameColor)) {
        if (strlen(ColorPlayer[iAuthor].sUsernameColor) == 6) {
            Format(sName, MAXLENGTH_NAME, "\x07%s%s", ColorPlayer[iAuthor].sUsernameColor, sName);
        } else if (strlen(ColorPlayer[iAuthor].sUsernameColor) == 8) {
            Format(sName, MAXLENGTH_NAME, "\x08%s%s", ColorPlayer[iAuthor].sUsernameColor, sName);
        } else {
            Format(sName, MAXLENGTH_NAME, "\x03%s", sName);
        }
    } else {
        Format(sName, MAXLENGTH_NAME, "\x03%s", sName);
    }
    if (CheckForward(iAuthor, sMessage, CT_TagColor)) {
        if (strlen(ColorPlayer[iAuthor].sTagColor) > 0) {
            if (StrEqual(ColorPlayer[iAuthor].sTagColor, "T", false)) {
                Format(sName, MAXLENGTH_NAME, "\x03%s%s", ColorPlayer[iAuthor].sTag);
            } else if(strlen(ColorPlayer[iAuthor].sTagColor) == 6) {
				Format(sName, MAXLENGTH_NAME, "\x07%s%s%s", ColorPlayer[iAuthor].sTagColor, ColorPlayer[iAuthor].sTag, sName);
			} else if(strlen(ColorPlayer[iAuthor].sTagColor) == 8) {
				Format(sName, MAXLENGTH_NAME, "\x08%s%s%s", ColorPlayer[iAuthor].sTagColor, ColorPlayer[iAuthor].sTag, sName);
			} else {
				Format(sName, MAXLENGTH_NAME, "\x01%s%s", ColorPlayer[iAuthor].sTag, sName);
			}
        }
    }
    int iMaxMessageLength = MAXLENGTH_MESSAGE - strlen(sName) - 5;
    if (strlen(ColorPlayer[iAuthor].sChatColor) > 0 && CheckForward(iAuthor, sMessage, CT_ChatColor)) {
        if(StrEqual(ColorPlayer[iAuthor].sChatColor, "T", false)) {
			Format(sMessage, iMaxMessageLength, "\x03%s", sMessage);
		} else if(strlen(ColorPlayer[iAuthor].sChatColor) == 6) {
			Format(sMessage, iMaxMessageLength, "\x07%s%s", ColorPlayer[iAuthor].sChatColor, sMessage);
		} else if(strlen(ColorPlayer[iAuthor].sChatColor) == 8) {
			Format(sMessage, iMaxMessageLength, "\x08%s%s", ColorPlayer[iAuthor].sChatColor, sMessage);
		}
    }


    return Plugin_Changed;
}*/

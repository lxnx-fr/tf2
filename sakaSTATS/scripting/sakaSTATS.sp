#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <dbi>
#include <multicolors>
#include <geoip>
#include <sdkhooks>
#include <tfdb>

#define PLUGIN_VERSION 			"1.0.3"
#define PLUGIN_NAME 			"sakaSTATS"
#define PLUGIN_AUTHOR 			"ѕαĸα"
#define PLUGIN_DESCRIPTION 		"Collects statistics"
#define PLUGIN_URL 				"https://tf2.l03.dev/"
#define SQL_QUERY_CREATE 		"CREATE TABLE IF NOT EXISTS sakaStats (steamid VARCHAR(100), name VARCHAR(100), kills INT, deaths INT, lastLogout INT, firstLogin INT, lastLogin INT, playtime INT, coins INT, points INT, topspeed INT, deflections INT);"

Handle DB = INVALID_HANDLE;
 
enum struct CachedStats {
	char sName[255];
	char sCountry[128];
	int iCoins;
	int iPoints;
	int iKills;
	int iDeaths;
	int iTopSpeed;
	int iPlayTime;
	int iLastLogin;
	int iFirstLogin;
	int iLastLogout;
	int iDeflections;
	int savedPoints;	
	bool bPlayerDied;
}

bool bStatsEnabled = false;
bool bBotFound = false;

/**
 * Config Values
 */
int cvMinRequiredPlayers = 3;
int cvSendWelcomeBackMsg = 1;
int cvSendFirstWelcomeMsg = 1;
int cvCountTopSpeedWithBots = 0;



/**
 * @todo
 * - Add "milestones/elos" > Get a specific Title/Permission after reaching an amount of Value in a Statistic (Points)
 * -  
 * 
 * 
 * 
 * 
 */

CachedStats StatsPlayer[MAXPLAYERS + 1];
KeyValues kvConfig;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	EngineVersion engineVersion = GetEngineVersion();
	if (engineVersion != Engine_TF2) {
		SetFailState("This plugin was made for use with Team Fortress 2 only.");
		return APLRes_Failure;
	} else return APLRes_Success;
} 

public void OnPluginStart() {
	PrintToServer("[sakaSTATS] Enabling Plugin (Version %s)", PLUGIN_VERSION);
	LoadTranslations("sakastats.phrases.txt");
	LoadConfig();
	InitDatabase(true);	
	RegServerCmd("sakastats", SakaStatsServerCommand);
	RegConsoleCmd("sm_stats", StatsCommand);
	RegConsoleCmd("sm_rank", StatsCommand);
	RegConsoleCmd("sm_place", PlaceCommand);
	RegConsoleCmd("sm_coins", CoinsCommand);
	RegConsoleCmd("sm_topspeed", TopSpeedCommand);
	RegConsoleCmd("sm_ts", TopSpeedCommand);
	RegConsoleCmd("sm_help", HelpCommand);
	HookEvent("arena_round_start", RoundStartEvent, EventHookMode_Post);
	HookEvent("teamplay_round_win", RoundEndEvent, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", PlayerSpawnEvent, EventHookMode_Pre);
	HookEvent("player_death", PlayerDeathEvent, EventHookMode_Post);
	LoadAllPlayersFromDB();
}

public void OnPluginEnd() {
	PrintToServer("[sakaSTATS] Disabling Plugin");
	LoadAllPlayersToDB();
	UnhookEvent("arena_round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	UnhookEvent("teamplay_round_win", RoundEndEvent, EventHookMode_PostNoCopy);
	InitDatabase(false);
}

public void InitDatabase(bool bConnect) {
	char sError[255];
	if (bConnect) {
		DB = SQL_Connect("sakastats", true, sError, sizeof(sError));
		if (DB == INVALID_HANDLE) {
	    	PrintToServer("[sakaSTATS] Could not connect to database: %s", sError);
	    	delete DB;
		}
		PrintToServer("[sakaSTATS] Connecting to database...");
		if (!SQL_FastQuery(DB, SQL_QUERY_CREATE)) {
			SQL_GetError(DB, sError, sizeof(sError));
			PrintToServer("[sakaSTATS] Failed to create stats table: %s", sError);
		}
	} else {
		delete DB;
	}
}

public void LoadConfig() {
	PrintToServer("[sakaSTATS] Loading Config file...");
	char sPath[64];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/sakastats.cfg");
	kvConfig = new KeyValues("sakastats");
	if (!kvConfig.ImportFromFile(sPath)) {
        SetFailState("Config file missing");
    }
	cvMinRequiredPlayers = kvConfig.GetNum("minRequiredPlayers");
	cvSendWelcomeBackMsg = kvConfig.GetNum("sendWelcomeBackMsg");
	cvSendFirstWelcomeMsg = kvConfig.GetNum("sendFirstWelcomeMsg");
	cvCountTopSpeedWithBots = kvConfig.GetNum("countTopSpeedWithBots");
}
/**
 * Plugin Events
 */
public Action PlayerDeathEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (IsValidClient(iVictim) && !IsFakeClient(iVictim)) {
		int iInflictor = GetEventInt(hEvent, "inflictor_entindex");
		int iIndex = TFDB_FindRocketByEntity(iInflictor);
		if (iIndex != -1) {
			StatsPlayer[iVictim].bPlayerDied = true;
			if (bStatsEnabled) {
				StatsPlayer[iAttacker].iKills++;
				StatsPlayer[iAttacker].iPoints += 2;
				//StatsPlayer[iAttacker].iPoints += CalculateAttackerPoints(0, 0);
				StatsPlayer[iVictim].iDeaths++;
				StatsPlayer[iVictim].iPoints -= 2;
			}
		}
	}
	return Plugin_Continue;
}
public Action PlayerSpawnEvent(Handle hEvent, char[] sEventName, bool bDontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	StatsPlayer[iClient].bPlayerDied = false;
	return Plugin_Continue;
}
public void OnEntityDestroyed(int iEntity) {
	if (iEntity == -1)
		return;
	int iIndex = TFDB_FindRocketByEntity(iEntity);
	if (iIndex == -1)
		return;
	if (!TFDB_IsValidRocket(iIndex)) 
		return;
	int iRocketTarget = TFDB_GetRocketTarget(iIndex);
	if (iRocketTarget == -1)
		return;
	int iTarget = EntRefToEntIndex(iRocketTarget);
	if (iTarget == -1)
		return;
	if (StatsPlayer[iTarget].bPlayerDied)
		return;
	float fRocketSpeed = TFDB_GetRocketMphSpeed(iIndex);
	float fRocketAdminSpeed = TFDB_GetRocketSpeed(iIndex);
	int iDeflections = TFDB_GetRocketDeflections(iIndex);
	CPrintToChatAll("%t", "OnEntityDestroyed", iTarget, fRocketSpeed, iDeflections, (iDeflections == 1 ? "Deflection" : "Deflections"), fRocketAdminSpeed);
}
public void TFDB_OnRocketDeflect(int iIndex, int iEntity, int iOwner) {
	if (!bBotFound || cvCountTopSpeedWithBots == 1) {
		int iSavedTopSpeed = StatsPlayer[iOwner].iTopSpeed;
		int iSavedDeflections = StatsPlayer[iOwner].iDeflections;
		int iCurrentTopSpeed = RoundToNearest(TFDB_GetRocketSpeed(iIndex));
		int iCurrentDeflections = TFDB_GetRocketDeflections(iIndex);
		if (iCurrentTopSpeed > iSavedTopSpeed) { 
			StatsPlayer[iOwner].iTopSpeed = iCurrentTopSpeed;
		}
		if (iCurrentDeflections > iSavedDeflections) {
			StatsPlayer[iOwner].iDeflections = iCurrentDeflections;
		}
	}
}
public void OnClientPutInServer(int iClient) {
	if (!IsEntityConnectedClient(iClient) || IsFakeClient(iClient)) return;
	GetPlayerCountry(iClient);
	if (PlayerExists(iClient)) {
		StatsPlayer[iClient].iLastLogin = GetTime();
		LoadPlayerFromDB(iClient, true);
	} else {
		CreatePlayer(iClient, true);
	}
}
public void OnClientDisconnect(int iClient) {
	if (!IsEntityConnectedClient(iClient) || IsFakeClient(iClient)) return;
	LoadPlayerToDB(iClient);
}
public Action RoundStartEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	bBotFound = IsPlayerVsBot();
	if (PlayerCountWithoutBots() >= cvMinRequiredPlayers ) {
		if (!bStatsEnabled) {
			CPrintToChatAll("%t", "RoundStart_StatsEnabled", PlayerCountWithoutBots(), cvMinRequiredPlayers);
		}
		bStatsEnabled = true; 
	} else {
		bStatsEnabled = false;
		CPrintToChatAll("%t", "RoundStart_StatsDisabled", PlayerCountWithoutBots(), cvMinRequiredPlayers);
	}
	return Plugin_Continue;
}
public Action RoundEndEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	LoadAllPlayersToDB();
	return Plugin_Continue;
}
public Action WelcomeBack(Handle hTimer, int iClient) {
	char sCountry[128];
	sCountry = StatsPlayer[iClient].sCountry;
	int iPoints = StatsPlayer[iClient].iPoints;
	int iRankingPoints = GetRanking(GetSteamId(iClient), "points");
	CPrintToChatAll("%t", "PlayerJoin_WelcomeBack", iClient, iRankingPoints, iPoints, sCountry);
	return Plugin_Continue;
}
public Action WelcomeFirst(Handle hTimer, int iClient) {
	char sCountry[128];
	sCountry = StatsPlayer[iClient].sCountry;
	CPrintToChatAll("%t", "PlayerJoin_FirstWelcome", iClient, sCountry);
	return Plugin_Continue;
}
/**
 * Help Command and Menu Management
 */
public Action HelpCommand(int iClient, int iArgs) {
	DrawHelpMenu(iClient);
	return Plugin_Handled;
}
public void DrawHelpMenu(int iClient) {
	Menu menu = new Menu(HelpMenuHandle);
	menu.SetTitle("Help Menu");
	menu.AddItem("0", "!stats - Watch Rankings & Your Stats");
	menu.AddItem("1", "!place - Show your Rank in Chat");
	menu.AddItem("2", "!cfp - Change your Footprint Color");
	menu.AddItem("3", "!fov - Change your FOV");
	menu.AddItem("4", "!tp | !fp - Change to Thirdperson/Firstperson");
	menu.AddItem("5", "!coins - Shows ur Coins");
	menu.AddItem("6", "!scc - Change Your Chat Color");
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int HelpMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch(action) {
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
/**
 * Stats Command and Menu Management
 */
public Action StatsCommand(int iClient, int iArgs) {
	DrawStatsMainMenu(iClient);
	return Plugin_Handled;
}
public void DrawStatsMainMenu(int iClient) {
	Menu menu = new Menu(StatsMainMenuHandle);
	menu.SetTitle("Stats Main Menu");
	menu.AddItem("0", "Your Stats");
	menu.AddItem("1", "Your Rankings");
	menu.AddItem("2", "Next 10 Players"); 
	menu.AddItem("3", "Global Ranking"); 
	menu.AddItem("4", "Settings");
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int StatsMainMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(iItem, sInfo, sizeof(sInfo));
			switch (iItem) {
				case 0: { DrawUserStats(iClient); }
				case 1: { DrawUserRankings(iClient); }
				case 2: { DrawNextPlayers(iClient); }
				case 3: { DrawRankingSelector(iClient); }
			}
		}
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
public void DrawUserStats(int iClient) {
	int iCachedPlaytime =  StatsPlayer[iClient].iPlayTime;
	int iSeconds = iCachedPlaytime + GetTime() - StatsPlayer[iClient].iLastLogin;
	char sFormatText[64];
	bool bZero = StatsPlayer[iClient].iKills > 0 && StatsPlayer[iClient].iDeaths > 0;
	int iSavedPoints = StatsPlayer[iClient].savedPoints;
	int iCurrentPoints = StatsPlayer[iClient].iPoints;
	Menu menu = new Menu(UserStatsMenuHandle);
	menu.SetTitle("Your Stats");
	
	Format(sFormatText, sizeof(sFormatText), "Kills: %i", StatsPlayer[iClient].iKills);
	menu.AddItem("0", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Deaths: %i", StatsPlayer[iClient].iDeaths);
	menu.AddItem("1", sFormatText, ITEMDRAW_DISABLED);
	if (bZero)
		Format(sFormatText, sizeof(sFormatText), "Kills/Deaths Ratio: %.2f", (StatsPlayer[iClient].iKills / StatsPlayer[iClient].iDeaths));
	else
		Format(sFormatText, sizeof(sFormatText), "Kills/Deaths Ratio: 0.0");
	menu.AddItem("2", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Points: %i", StatsPlayer[iClient].iPoints);
	menu.AddItem("3", sFormatText, ITEMDRAW_DISABLED);
	if (iCurrentPoints >= iSavedPoints) 
		Format(sFormatText, sizeof(sFormatText), "Points gained: +%i", (iCurrentPoints - iSavedPoints));
	else
		Format(sFormatText, sizeof(sFormatText), "Points gained: -%i", (iSavedPoints - iCurrentPoints));
	menu.AddItem("4", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Coins: %i", StatsPlayer[iClient].iCoins);
	menu.AddItem("5", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Playtime: %s", GeneratePlaytimeString(iSeconds));
	menu.AddItem("6", sFormatText, ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int UserStatsMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch (action) {
		case MenuAction_Cancel: { if (iItem == MenuCancel_ExitBack) { DrawStatsMainMenu(iClient); } }
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
public void DrawUserRankings(int iClient) {
	Menu menu = new Menu(UserRankingsMenuHandle);
	menu.SetTitle("Your Rankings");
	char sFormatText[64];
	Format(sFormatText, sizeof(sFormatText), "Points: #%i", GetRanking(GetSteamId(iClient), "points"));
	menu.AddItem("0", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Coins: #%i", GetRanking(GetSteamId(iClient), "coins"));
	menu.AddItem("1", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Kills: #%i", GetRanking(GetSteamId(iClient), "kills"));
	menu.AddItem("2", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Top Speed: #%i", GetRanking(GetSteamId(iClient), "topspeed"));
	menu.AddItem("3", sFormatText, ITEMDRAW_DISABLED);
	Format(sFormatText, sizeof(sFormatText), "Playtime: #%i", GetRanking(GetSteamId(iClient), "playtime"));
	menu.AddItem("4", sFormatText, ITEMDRAW_DISABLED);
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int UserRankingsMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch (action) {
		case MenuAction_Cancel: { if (iItem == MenuCancel_ExitBack) { DrawStatsMainMenu(iClient); } }
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
public void DrawRankingSelector(int iClient) {
	Menu menu = new Menu(RankingSelectorMenuHandle);
	menu.SetTitle("Select your Ranking Type");
	menu.AddItem("0", "Points");
	menu.AddItem("1", "Coins");
	menu.AddItem("2", "Kills");
	menu.AddItem("3", "Top Speed");
	menu.AddItem("4", "Playtime");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int RankingSelectorMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch(action) {
		case MenuAction_Select: {
			switch(iItem) {
				case 0: { DrawPlayerRanking(iClient, "points"); }
				case 1: { DrawPlayerRanking(iClient, "coins"); }
				case 2: { DrawPlayerRanking(iClient, "kills"); }
				case 3: { DrawPlayerRanking(iClient, "topspeed"); }
				case 4: { DrawPlayerRanking(iClient, "playtime"); }
			}
		}
		case MenuAction_Cancel: { if (iItem == MenuCancel_ExitBack) { DrawStatsMainMenu(iClient); } }
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
public void DrawPlayerRanking(int iClient, char[] sRankingType) {
	Menu menu = new Menu(PlayerRankingMenuHandle);
	menu.SetTitle("Stats | Top 100");
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT steamid, name, %s FROM sakaStats ORDER BY %s DESC LIMIT 100;", sRankingType, sRankingType);
	DBResultSet rsQuery = SQL_Query(DB, sQuery, sizeof(sQuery));
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] DrawPlayerRanking(false) Failed to query (error: %s)", sError);
	} else {
		char sName[MAX_NAME_LENGTH], sSteamId[32], sMenuText[128];
		int iRankingValue = 0;
		int iRank = 0;
		while (SQL_FetchRow(rsQuery)) {
			iRank++;
			SQL_FetchString(rsQuery, 0, sSteamId, sizeof(sSteamId));
			SQL_FetchString(rsQuery, 1, sName, sizeof(sName));
			iRankingValue = SQL_FetchInt(rsQuery, 2);
			if (StrEqual(sRankingType, "playtime", false)) {
				Format(sMenuText, sizeof(sMenuText), "#%i - %s - %s", iRank, sName, GeneratePlaytimeString(iRankingValue));
			} else if (StrEqual(sRankingType, "topspeed", false)) {
				Format(sMenuText, sizeof(sMenuText), "#%i - %s - %.0f mph", iRank, sName, CalculateSpeed(iRankingValue));
			} else if (StrEqual(sRankingType, "kills", false)) {
				Format(sMenuText, sizeof(sMenuText), "#%i - %s - %i Kills", iRank, sName, iRankingValue);
			} else if (StrEqual(sRankingType, "coins", false)) {
				Format(sMenuText, sizeof(sMenuText), "#%i - %s - %i Coins", iRank, sName, iRankingValue);
			} else if (StrEqual(sRankingType, "points", false)) {
				Format(sMenuText, sizeof(sMenuText), "#%i - %s - %i Points", iRank, sName, iRankingValue);
			} else {
				Format(sMenuText, sizeof(sMenuText), "Some error");
			}
			menu.AddItem(sSteamId, sMenuText, ITEMDRAW_DEFAULT);
		}
	}
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int PlayerRankingMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch(action) {
		case MenuAction_Cancel: { if (iItem == MenuCancel_ExitBack) { DrawRankingSelector(iClient); } }
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
public void DrawNextPlayers(int iClient) {
	Menu menu = new Menu(NextPlayersMenuHandle);
	menu.SetTitle("Stats | Next 10 Players");
	int iPlayerRank = GetRanking(GetSteamId(iClient), "points");
	int iCurrentPoints = StatsPlayer[iClient].iPoints;
	int iNextPlayers = iPlayerRank - 11;
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT steamid, name, points FROM sakaStats WHERE points >= %i ORDER BY points DESC LIMIT %i,11;", iCurrentPoints, (iNextPlayers < 0 ? 0 : iNextPlayers));
	DBResultSet rsQuery = SQL_Query(DB, sQuery, sizeof(sQuery));
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] DrawNextPlayers() Failed to Query (error: %s)", sError);
	} else {
		char sName[MAX_NAME_LENGTH], sSteamId[32], sMenuText[128];
		if (iNextPlayers < 1)
			iNextPlayers = 1; 
		while(SQL_FetchRow(rsQuery)) {
			SQL_FetchString(rsQuery, 0, sSteamId, sizeof(sSteamId));
			SQL_FetchString(rsQuery, 1, sName, sizeof(sName));
			Format(sMenuText, sizeof(sMenuText), "#%i - %s - %i Points", iNextPlayers, sName, SQL_FetchInt(rsQuery, 2));
			menu.AddItem(sSteamId, sMenuText);
			iNextPlayers++;
		}
	}
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int NextPlayersMenuHandle(Menu menu, MenuAction action, int iClient, int iItem) {
	switch (action) {
		case MenuAction_Cancel: {
			if (iItem == MenuCancel_ExitBack) { DrawStatsMainMenu(iClient); }
		}
		case MenuAction_End: { delete menu; }
	}
	return 0;
}
/**
 * Misc Commands
 */
public Action PlaceCommand(int iClient, int iArgs) {
	int iRanking = GetRanking(GetSteamId(iClient), "points");
	int iAllPlayers = GetRowCount();
	CPrintToChatAll("%t", "Command_Place", iClient, iRanking, iAllPlayers, StatsPlayer[iClient].iPoints);
	return Plugin_Handled;
}
public Action CoinsCommand(int iClient, int iArgs) {
	int iCoins = StatsPlayer[iClient].iCoins;
	CPrintToChat(iClient, "%t", "Command_Coins", iCoins);
	return Plugin_Handled;
}
public Action TopSpeedCommand(int iClient, int iArgs) {
	int iAdminSpeed = StatsPlayer[iClient].iTopSpeed;
	int iDeflections = StatsPlayer[iClient].iDeflections;
	float fSpeed = CalculateSpeed(iAdminSpeed); 
	CPrintToChat(iClient, "%t", "Command_TopSpeed", fSpeed, iDeflections);
	return Plugin_Handled;
}
public Action SakaStatsServerCommand(int iArgs) {
	if (iArgs == 1) {
		char cFirstArg[32];
		GetCmdArg(1, cFirstArg, sizeof(cFirstArg));
		if (StrEqual(cFirstArg, "listplayers", false) || StrEqual(cFirstArg, "lp", false)) {
			PrintToServer("[sakaSTATS] List of connected Players | Start");
			for (int client = -1; client <= MaxClients; client++) {
				if (IsEntityConnectedClient(client))
					PrintToServer("iClient: %i steamId: %s nickname: %N ", client, GetSteamId(client), client);
			}
			PrintToServer("[sakaSTATS] List of connected Players | End");
		}
	} else if(iArgs == 3) {
		char cFirstArg[255]; // command name
		GetCmdArg(1, cFirstArg, sizeof(cFirstArg));
		char cSecondArg[255]; // statistic type
		GetCmdArg(2, cSecondArg, sizeof(cSecondArg));
		char cThirdArg[255]; // steamid
		GetCmdArg(3, cThirdArg, sizeof(cThirdArg));
		if (StrEqual(cFirstArg, "rankbyuser", false)) {
			if (StrEqual(cSecondArg, "points", false) || StrEqual(cSecondArg, "playtime", false) || StrEqual(cSecondArg, "coins", false)  || StrEqual(cSecondArg, "topspeed", false) || StrEqual(cSecondArg, "kills", false) || StrEqual(cSecondArg, "deaths", false)) {
				PrintToServer("[sakaSTATS] Command: rankbyuser Statistic: %s SteamID: %s Rank: %i", cSecondArg, cThirdArg, GetRanking(cThirdArg, cSecondArg));
			} else {
				PrintToServer("[sakaSTATS] Statistic not found! Use: points, coins, topSpeed, playtime, kills, deaths");
			}
		} else if (StrEqual(cFirstArg, "updatetopspeed", false)) {
			int iTarget = StringToInt(cSecondArg);
			int newSpeed = StringToInt(cThirdArg);
			if (IsEntityConnectedClient(iTarget) && !IsFakeClient(iTarget)) {
				if (newSpeed > StatsPlayer[iTarget].iTopSpeed) {
					StatsPlayer[iTarget].iTopSpeed = newSpeed;
				}
			} else {
				PrintToServer("[sakaSTATS] Target was not found or is a bot: %i", iTarget);
			}
		
		} else {
			PrintToServer("[sakaSTATS] Command not found");
		}
	} else if (iArgs == 4) {
		char cFirstArg[255]; // command name
		GetCmdArg(1, cFirstArg, sizeof(cFirstArg));
		char cSecondArg[255]; // statistic type
		GetCmdArg(2, cSecondArg, sizeof(cSecondArg));
		char cThirdArg[255]; // rank
		GetCmdArg(3, cThirdArg, sizeof(cThirdArg));
		char cFourthArg[255]; // choose id / name
		GetCmdArg(4, cFourthArg, sizeof(cFourthArg));
		if (StrEqual(cFirstArg, "userbyrank", false)) {
			if (StrEqual(cSecondArg, "points", false) || StrEqual(cSecondArg, "playTime", false) || StrEqual(cSecondArg, "coins", false)  || StrEqual(cSecondArg, "topspeed", true) || StrEqual(cSecondArg, "kills", true) || StrEqual(cSecondArg, "deaths", true)) {
				int iThirdArg = StringToInt(cThirdArg); // rank
				int identifier = StrEqual(cFourthArg, "id", false) ? 0 : 1;
				PrintToServer("[sakaSTATS] UserByRank Statistic: %s Rank: %i Name/SteamID: %s", cSecondArg, iThirdArg, GetUserByRank(iThirdArg - 1, cSecondArg, identifier));
			} else {
				PrintToServer("[sakaSTATS] Statistic not found! Use: points, coins, topspeed, playtime, kills, deaths");
			}
		} else {
			PrintToServer("[sakaSTATS] Command not found");
		}
	} else if (iArgs == 5) {
		char cFirstArg[30]; // command name
		GetCmdArg(1, cFirstArg, sizeof(cFirstArg));
		if (StrEqual(cFirstArg, "setcachedstats", false)) {
			char cSecondArg[20]; // statistic type
			GetCmdArg(2, cSecondArg, sizeof(cSecondArg));
			if (StrEqual(cSecondArg, "points", false) || StrEqual(cSecondArg, "playtime", false) || StrEqual(cSecondArg, "coins", false)  || StrEqual(cSecondArg, "topspeed", false) || StrEqual(cSecondArg, "kills", false) || StrEqual(cSecondArg, "deaths", false)) { 
				char cThirdArg[32]; // local id
				GetCmdArg(3, cThirdArg, sizeof(cThirdArg));
				int localClient = StringToInt(cThirdArg );
				if (IsEntityConnectedClient(localClient) && !IsFakeClient(localClient)) {
					char cFourthArg[10]; // new statistic value
					GetCmdArg(4, cFourthArg, sizeof(cFourthArg));
					int cNewValue = StringToInt(cFourthArg);
					char cFifthArg[10]; // add remove set
					GetCmdArg(5, cFifthArg, sizeof(cFifthArg));
					if (StrEqual(cFifthArg, "add", false)) {
						if (StrEqual(cSecondArg, "points", false)) {
							StatsPlayer[localClient].iPoints += cNewValue;
						} else if (StrEqual(cSecondArg, "playtime", false)) {
							StatsPlayer[localClient].iPlayTime += cNewValue;
						} else if (StrEqual(cSecondArg, "coins", false)) {
							StatsPlayer[localClient].iCoins += cNewValue;
						} else if (StrEqual(cSecondArg, "topspeed", false)) {
							StatsPlayer[localClient].iTopSpeed += cNewValue;
						} else if (StrEqual(cSecondArg, "kills", false)) {
							StatsPlayer[localClient].iKills += cNewValue;
						} else if (StrEqual(cSecondArg, "deaths", false)) {
							StatsPlayer[localClient].iDeaths += cNewValue;
						}
					} else if (StrEqual(cFifthArg, "set", false)) {
						if (StrEqual(cSecondArg, "points", false)) {
							StatsPlayer[localClient].iPoints = cNewValue;
						} else if (StrEqual(cSecondArg, "playtime", false)) {
							StatsPlayer[localClient].iPlayTime = cNewValue;
						} else if (StrEqual(cSecondArg, "coins", false)) {
							StatsPlayer[localClient].iCoins = cNewValue;
						} else if (StrEqual(cSecondArg, "topspeed", false)) {
							StatsPlayer[localClient].iTopSpeed = cNewValue;
						} else if (StrEqual(cSecondArg, "kills", false)) {
							StatsPlayer[localClient].iKills = cNewValue;
						} else if (StrEqual(cSecondArg, "deaths", false)) {
							StatsPlayer[localClient].iDeaths = cNewValue;
						}
					} else if (StrEqual(cFifthArg, "remove", false)) {
						if (StrEqual(cSecondArg, "points", false)) {
							StatsPlayer[localClient].iPoints -= cNewValue;
						} else if (StrEqual(cSecondArg, "playtime", false)) {
							StatsPlayer[localClient].iPlayTime -= cNewValue;
						} else if (StrEqual(cSecondArg, "coins", false)) {
							StatsPlayer[localClient].iCoins -= cNewValue;
						} else if (StrEqual(cSecondArg, "topspeed", false)) {
							StatsPlayer[localClient].iTopSpeed -= cNewValue;
						} else if (StrEqual(cSecondArg, "kills", false)) {
							StatsPlayer[localClient].iKills -= cNewValue;
						} else if (StrEqual(cSecondArg, "deaths", false)) {
							StatsPlayer[localClient].iDeaths -= cNewValue;
						}
					} else {
						PrintToServer("[sakaSTATS] Type not found! Use: add / remove / set");
					}			
				} else {
					PrintToServer("[sakaSTATS] Client %i is a bot/not online/could not be found", localClient);
				}
			} else {
				PrintToServer("[sakaSTATS] Statistic not found! Use: points, coins, topspeed, playtime, kills, deaths");
			}
		} 
	} else {
		PrintToServer("[sakaSTATS] Plugin Version: %s", PLUGIN_VERSION);
		PrintToServer("[sakaSTATS] Command usages:");
		PrintToServer("sakastats listplayers");
		PrintToServer("sakastats userbyrank <statistic> <rank> <id/name>");
		PrintToServer("sakastats rankbyuser <statistic> <steamid>");
		PrintToServer("sakastats updatetopspeed <client> <new speed>");
		PrintToServer("sakastats setcachedstats <statistic> <client> <value> <add/set/remove>");
	} 
	return Plugin_Handled;
}
/**
 * Dynamic Values
 */
stock char[] GeneratePlaytimeString(int iMySQLPlaytime) {
	int iSeconds = iMySQLPlaytime;
	int iMinutes = 0;
	int iHours = 0;
	int iDays = 0;
	char cFormatPlaytime[64];
	while(iSeconds > 60) {
		iSeconds -= 60;
		iMinutes += 1;
	}
	while(iMinutes > 60) {
		iMinutes -= 60;
		iHours += 1;
	}
	while(iHours > 24) {
		iHours -= 24;
		iDays += 1;
	}
	Format(cFormatPlaytime, sizeof(cFormatPlaytime), "%id%ih%im%is", iDays, iHours, iMinutes, iSeconds);
	return cFormatPlaytime;
}
stock char[] GetSteamId(int iClient) {
	char sSteamId[32];
	if (IsEntityConnectedClient(iClient)) {
		GetClientAuthId(iClient, AuthId_Steam2, sSteamId, sizeof(sSteamId), true);
	}
	return sSteamId;
}
stock char[] GetUserByRank(int iRank, char[] sStatistic, int iIdentifier) {
	char sName[MAX_NAME_LENGTH];
	char sQuery[300];
	Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaStats ORDER BY %s DESC;", sStatistic);
	DBResultSet rsQuery = SQL_Query(DB, sQuery, sizeof(sQuery));
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] GetUserByRank(Error) Failed to Query (error: %s)", sError);
	} else {
		int iCurrentRow = 0;
		while (iCurrentRow <= iRank) {
			if (SQL_MoreRows(rsQuery)) {
				SQL_FetchRow(rsQuery);
				if (iCurrentRow == iRank) {
					SQL_FetchString(rsQuery, iIdentifier, sName, sizeof(sName));
					break;
				} else iCurrentRow++;
			}
		}
	}
	return sName;
}
stock float CalculateSpeed(int iSpeed){
	return iSpeed * (15.0 / 350.0);
}
stock int GetRowCount() {
	int iRowCount = -1;
	char sQuery[48] = "SELECT * FROM sakaStats;";
	DBResultSet rsQuery = SQL_Query(DB, sQuery, sizeof(sQuery));
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] GetRowCount(Error) Failed to Query (error: %s)", sError);
	} else iRowCount = SQL_GetRowCount(rsQuery);
	return iRowCount;
}
stock int CountPlayers(bool bAlive) {
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (IsValidClient(iClient, bAlive))iCount++;
	}
	return iCount;
}
stock int GetRanking(char[] sSteamId, char[] sStatistic) {
	int iCurrentRank = -1;
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT COUNT(*) AS rank FROM sakaStats WHERE %s>=(SELECT %s FROM sakaStats WHERE steamid='%s');", sStatistic, sStatistic, sSteamId);
	DBResultSet rsQuery = SQL_Query(DB, sQuery, sizeof(sQuery));
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] GetRanking(Error) Failed to Query (error: %s)", sError);
	} else {
		SQL_FetchRow(rsQuery);
		iCurrentRank = SQL_FetchInt(rsQuery, 0);
	}
	return iCurrentRank;
}
stock bool IsValidClient(int iClient, bool bAlive = false) {
	if (iClient >= 1 && 
		iClient <= MaxClients && 
		IsClientConnected(iClient) && 
		IsClientInGame(iClient) && 
		(bAlive == false || IsPlayerAlive(iClient))) {
		return true;
	}
	return false;
}
stock bool IsEntityConnectedClient(int iEntity) {
	return 0 < iEntity <= MaxClients && IsClientInGame(iEntity);
}
stock bool PlayerExists(int iClient) {
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaStats WHERE steamid ='%s';", GetSteamId(iClient));
	DBResultSet rsQuery = SQL_Query(DB, sQuery);
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] PlayerExists(Error) Failed to Query (error: %s)", sError);
		return false;
	} else {
		return SQL_GetRowCount(rsQuery) > 0;
	}
}
stock bool GetPlayerCountry(int iClient) {
	bool bCountryFailed = false;
	bool bIPFailed = false;
	char sCountryName[128];
	char sClientIP[128];
	if (!GetClientIP(iClient, sClientIP, sizeof(sClientIP), true)) {
		PrintToServer("[sakaSTATS] GetPlayerCountry() IP-Adress not found: %N", iClient);
		bIPFailed = true;
	}
	if (!GeoipCountry(sClientIP, sCountryName, sizeof(sCountryName)) || bIPFailed) {
		PrintToServer("[sakaSTATS] GetPlayerCountry() Country not found: %N", iClient);
		bCountryFailed = true;
	}
	PrintToServer("[sakaSTATS] Player Countr of %N: %s", iClient, sCountryName);
	StatsPlayer[iClient].sCountry = ((bIPFailed && bCountryFailed) ? "Not Found" : sCountryName);
	return bIPFailed && bCountryFailed;
}
stock bool IsPlayerVsBot() {
	bool bBot = false;
	for (int i = 1; i < MaxClients; i++) {
		if (IsEntityConnectedClient(i) && IsFakeClient(i)) {
			bBot = true;
			break;
		}
	}
	return bBot;
}
stock int PlayerCountWithoutBots() {
	int iCount = 0;
	for (int i = 1; i < MaxClients; i++) {
		if (IsEntityConnectedClient(i) && IsClientConnected(i) && !IsFakeClient(i) && (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)) {
			iCount++;
		}
	}
	return iCount;
} 
stock int CalculateVictimPoints(int iAttackerRank, int iVictimRank) {
	int iDifference = 2;
	return iDifference;
}
stock int CalculateAttackerPoints(int iAttackerRank, int iVictimRank) {
	int iDifference = 2;
	return iDifference;
}
/**
 * Player Database Functions
 */
public void CreatePlayer(int iClient, bool bMessage) {
	char sQuery[500];
	char sClientName[MAX_NAME_LENGTH];
	GetClientName(iClient, sClientName, sizeof(sClientName));
	int iLoginTime = GetTime();
	Format(sQuery, sizeof(sQuery), "INSERT INTO sakaStats (steamid,name,kills,deaths,lastLogout,firstLogin,lastLogin,playtime,coins,points,topSpeed,deflections) VALUES ('%s', '%s', '0', '0', '0', '%i', '%i', '0', '0', '1000', '0', '0');", GetSteamId(iClient), sClientName, iLoginTime, iLoginTime);
	if (!SQL_FastQuery(DB, sQuery)){ 
		char sError[255]; 
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] CreatePlayer(): Failed to Query (error: %s)", sError);
	}
	StatsPlayer[iClient].sName = sClientName;
	StatsPlayer[iClient].iLastLogout = 0;
	StatsPlayer[iClient].iFirstLogin = iLoginTime;
	StatsPlayer[iClient].iLastLogin = iLoginTime;
	StatsPlayer[iClient].iKills = 0;
	StatsPlayer[iClient].iDeaths = 0;
	StatsPlayer[iClient].iPlayTime = 0;
	StatsPlayer[iClient].iCoins = 0;
	StatsPlayer[iClient].iTopSpeed = 0;
	StatsPlayer[iClient].iDeflections = 0;
	StatsPlayer[iClient].savedPoints = 1000;
	PrintToServer("[sakaSTATS] CreatePlayer(): %N", iClient);
	if (bMessage && cvSendFirstWelcomeMsg == 1)
		CreateTimer(3.0, WelcomeFirst, iClient);		
}
public void LoadPlayerFromDB(int iClient, bool bMessage) {
	char sQuery[255];
	Format(sQuery, sizeof(sQuery), "SELECT * FROM sakaStats WHERE steamid ='%s';", GetSteamId(iClient));
	DBResultSet rsQuery = SQL_Query(DB, sQuery);
	if (rsQuery == null) {
		char sError[255];
		SQL_GetError(DB, sError, sizeof(sError));
		PrintToServer("[sakaSTATS] LoadPlayerFromDB(): Failed to query error: %s", sError);
	} else {
		SQL_FetchRow(rsQuery);
		StatsPlayer[iClient].iKills = SQL_FetchInt(rsQuery, 2);
		StatsPlayer[iClient].iDeaths = SQL_FetchInt(rsQuery, 3);
		StatsPlayer[iClient].iLastLogout = SQL_FetchInt(rsQuery, 4);
		StatsPlayer[iClient].iFirstLogin = SQL_FetchInt(rsQuery, 5);
		StatsPlayer[iClient].iLastLogin = GetTime();
		StatsPlayer[iClient].iPlayTime = SQL_FetchInt(rsQuery, 7);
		StatsPlayer[iClient].iCoins = SQL_FetchInt(rsQuery, 8);
		StatsPlayer[iClient].savedPoints = SQL_FetchInt(rsQuery, 9);
		StatsPlayer[iClient].iPoints = SQL_FetchInt(rsQuery, 9);
		StatsPlayer[iClient].iTopSpeed = SQL_FetchInt(rsQuery, 10);
		StatsPlayer[iClient].iDeflections = SQL_FetchInt(rsQuery, 11);
		char sClientName[MAX_NAME_LENGTH];
		GetClientName(iClient, sClientName, sizeof(sClientName));
		StatsPlayer[iClient].sName = sClientName;
		PrintToServer("[sakaSTATS] LoadPlayerFromDB(): %N", iClient);
		if (bMessage && cvSendWelcomeBackMsg == 1)
			CreateTimer(3.0, WelcomeBack, iClient);
	}
}
public void LoadPlayerToDB(int iClient) {
	char sQuery[255];
	char sClientName[MAX_NAME_LENGTH];
	GetClientName(iClient, sClientName, sizeof(sClientName));
	int iKills = StatsPlayer[iClient].iKills;
	int iDeaths = StatsPlayer[iClient].iDeaths;
	int iLastLogin = StatsPlayer[iClient].iLastLogin;
	int iPlaytime = StatsPlayer[iClient].iPlayTime;
	int iCoins = StatsPlayer[iClient].iCoins;
	int iPoints = StatsPlayer[iClient].iPoints;
	int iTopSpeed = StatsPlayer[iClient].iTopSpeed;
	int iDeflections = StatsPlayer[iClient].iDeflections;
	int iFinalTime = iPlaytime + GetTime() - iLastLogin;
	Format(sQuery, sizeof(sQuery), "UPDATE sakaStats SET name='%s',kills='%i',deaths='%i',lastLogout='%i',lastLogin='%i',playtime='%i',coins='%i',points='%i',topspeed='%i',deflections='%i' WHERE steamid='%s'", sClientName, iKills, iDeaths, GetTime(), iLastLogin, iFinalTime, iCoins, iPoints, iTopSpeed, iDeflections, GetSteamId(iClient));
	SQL_FastQuery(DB, sQuery);
	PrintToServer("[sakaSTATS] LoadPlayerToDB(): %N", iClient);
}
public void LoadAllPlayersToDB() {
	for (int i = 1; i < MaxClients; i++) {
		if (IsEntityConnectedClient(i) && !IsFakeClient(i)) { 
			if (PlayerExists(i)) { LoadPlayerToDB(i); }
			else { CreatePlayer(i, false); }
		}
	}
}
public void LoadAllPlayersFromDB() {
	for (int client = 1; client < MaxClients; client++) {
		if (IsEntityConnectedClient(client) && !IsFakeClient(client)) { LoadPlayerFromDB(client, false); }
	}
}



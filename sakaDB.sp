#pragma semicolon 1	

/* PLUGIN INFO: Yet Another Dodgeball Plugin (Modified by SAKA)
 * PD.1 #INCLUDES
 * PD.2 #DEFINATIONS
 * PD.3 #ENUMS
 * PD.4 #CONFIG VARS
 * PD.5 #GAMEPLAY VARS
 * PD.6 #ROCKET VARS
 * PD.7 #PLUGIN START/END
 * PD.8 #COMMANDS 							(8:1, 8:2, 8:3, 8:4, 8:5, 8:6)
 * PD.9 #EVENTS 
 * PD.10 #SOURCE MOD EVENTS
 * PD.11 #FUNCTIONS 
 *
 * 
 *
 *
 *
 *
 */

//
// PD.1 #INCLUDES
//

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <morecolors>

//
// PD.2 #DEFINATIONS
//
#pragma newdecls required
#define PLUGIN_NAME 			"Yet Another Dodgeball (Modified by saka)"
#define PLUGIN_AUTHOR 			"Damizean Edited by blood, lizzy and saka"
#define PLUGIN_VERSION			"1.4.3"
#define PLUGIN_CONTACT			"laurinfrank2@gmail.com"
#define FPS_LOGIC_RATE			20.0
#define FPS_LOGIC_INTERVAL		1.0 / FPS_LOGIC_RATE
#define MAX_ROCKETS				100
#define MAX_ROCKET_CLASSES		50
#define MAX_SPAWNER_CLASSES		50
#define MAX_SPAWN_POINTS		100
#define PYROVISION_ATTRIBUTE 	"vision opt in flags"
#define	MAX_EDICT_BITS			11
#define	MAX_EDICTS				(1 << MAX_EDICT_BITS)
#define SOUND_DEFAULT_SPAWN				"weapons/sentry_rocket.wav"
#define SOUND_DEFAULT_BEEP				"weapons/sentry_scan.wav"
#define SOUND_DEFAULT_ALERT				"weapons/sentry_spot.wav"
#define SOUND_DEFAULT_SPEEDUPALERT		"misc/doomsday_lift_warning.wav"
#define SNDCHAN_MUSIC					32
#define PARTICLE_NUKE_1					"fireSmokeExplosion"
#define PARTICLE_NUKE_2					"fireSmokeExplosion1"
#define PARTICLE_NUKE_3					"fireSmokeExplosion2"
#define PARTICLE_NUKE_4					"fireSmokeExplosion3"
#define PARTICLE_NUKE_5					"fireSmokeExplosion4"
#define PARTICLE_NUKE_COLLUMN			"fireSmoke_collumnP"
#define PARTICLE_NUKE_1_ANGLES			view_as<float> ({270.0, 0.0, 0.0})
#define PARTICLE_NUKE_2_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_3_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_4_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_5_ANGLES			PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_COLLUMN_ANGLES	PARTICLE_NUKE_1_ANGLES
#define TestFlags(%1,%2)	(!!((%1) & (%2)))
#define TestFlagsAnd(%1,%2) (((%1) & (%2)) == %2)
// Particlessss
//int g_RocketParticle[MAXPLAYERS + 1];

//
// PD.3 #ENUMS
//
enum BehaviourTypes {
	Behaviour_Unknown, 
	Behaviour_Homing
};
enum RocketFlags {
	RocketFlag_None = 0, 
	RocketFlag_PlaySpawnSound = 1 << 0, 
	RocketFlag_PlayBeepSound = 1 << 1, 
	RocketFlag_PlayAlertSound = 1 << 2, 
	RocketFlag_ElevateOnDeflect = 1 << 3, 
	RocketFlag_IsNeutral = 1 << 4, 
	RocketFlag_Exploded = 1 << 5, 
	RocketFlag_OnSpawnCmd = 1 << 6, 
	RocketFlag_OnDeflectCmd = 1 << 7, 
	RocketFlag_OnKillCmd = 1 << 8, 
	RocketFlag_OnExplodeCmd = 1 << 9, 
	RocketFlag_CustomModel = 1 << 10, 
	RocketFlag_CustomSpawnSound = 1 << 11, 
	RocketFlag_CustomBeepSound = 1 << 12, 
	RocketFlag_CustomAlertSound = 1 << 13, 
	RocketFlag_Elevating = 1 << 14, 
	RocketFlag_IsAnimated = 1 << 15
};
enum RocketSound {
	RocketSound_Spawn, 
	RocketSound_Beep, 
	RocketSound_Alert
};
enum SpawnerFlags {
	SpawnerFlag_Team_Red = 1, 
	SpawnerFlag_Team_Blu = 2, 
	SpawnerFlag_Team_Both = 3
};
enum eRocketSteal {
	stoleRocket = false, 
	rocketsStolen
};

//
// PD.4 #CONFIG VARS
//
Handle CVAR_Enabled;
Handle CVAR_EnableCfgFile;
Handle CVAR_DisableCfgFile;
Handle CVAR_HudSpeedo;
Handle CVAR_KillAnnounce;
Handle CVAR_AutoPyroVision = INVALID_HANDLE;
Handle CVAR_AirBlastCMD;
Handle CVAR_DeflectCountAnnounce;
Handle CVAR_RedirectBeep;
Handle CVAR_PreventTauntKills;
Handle CVAR_StealPrevention;
Handle CVAR_StealPreventionCount;
Handle CVAR_DelayPrevention;
Handle CVAR_DelayPreventionTime;
Handle CVAR_DelayPreventionSpeedup;

//
// PD.5 #GAMEPLAY VARS
//
/* PLAYER VARS */
int PVAR_AIRBLAST_PREVENTION[MAXPLAYERS + 1];
int PVAR_FIRST_JOINED[MAXPLAYERS + 1];
int PVAR_STOLEN_ROCKETS[MAXPLAYERS + 1];
int bStealArray[MAXPLAYERS + 1][eRocketSteal];


int g_nBounces[MAX_EDICTS];
Handle CVAR_MaxRocketBounces;
int g_config_iMaxBounces = 10000;



bool g_pluginEnabled; // Is the plugin enabled?
bool g_mapIsTFDB; // Idea taken from SirDigby
bool g_roundStarted; // Has the round started?
int g_roundCount; // Current round count since map start
int g_rocketsFired; // No. of rockets fired since round start
Handle g_logicTimer; // Logic timer
float g_lastSpawnTime; // Time at which the last rocket had spawned
float g_nextSpawnTime; // Time at which the next rocket will be able to spawn
int g_lastDeadTeam; // The team of the last dead client. If none, it's a random team.
int g_lastDeadClient; // The last dead client. If none, it's a random client.
int g_playerCount;
Handle g_hud;
int g_lastRocketSpeed;
Handle g_timerHud;


//
// PD.6 #ROCKET VARS
// 
bool g_bRocketIsValid[MAX_ROCKETS];
bool g_bRocketIsNuke[MAX_ROCKETS];
bool g_bPreventingDelay;
int g_iRocketEntity[MAX_ROCKETS];
int g_iRocketTarget[MAX_ROCKETS];
int g_iRocketSpawner[MAX_ROCKETS];
int g_iRocketClass[MAX_ROCKETS];
RocketFlags g_iRocketFlags[MAX_ROCKETS];
float g_fRocketSpeed[MAX_ROCKETS];
float g_fRocketDirection[MAX_ROCKETS][3];
int g_iRocketDeflections[MAX_ROCKETS];
float g_fRocketLastDeflectionTime[MAX_ROCKETS];
float g_fRocketLastBeepTime[MAX_ROCKETS];
int g_iLastCreatedRocket;
int g_iRocketCount;
float g_fSavedSpeed;
float g_fSavedSpeedIncrement;


// Classes
char g_strRocketClassName[MAX_ROCKET_CLASSES][16];
char g_strRocketClassLongName[MAX_ROCKET_CLASSES][32];
char g_strSavedClassName[32];
BehaviourTypes g_iRocketClassBehaviour[MAX_ROCKET_CLASSES];
char g_strRocketClassModel[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
RocketFlags g_iRocketClassFlags[MAX_ROCKET_CLASSES];
float g_fRocketClassBeepInterval[MAX_ROCKET_CLASSES];
char g_strRocketClassSpawnSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
char g_strRocketClassBeepSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
char g_strRocketClassAlertSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
float g_fRocketClassCritChance[MAX_ROCKET_CLASSES];
float g_fRocketClassDamage[MAX_ROCKET_CLASSES];
float g_fRocketClassDamageIncrement[MAX_ROCKET_CLASSES];
float g_fRocketClassSpeed[MAX_ROCKET_CLASSES];
float g_fRocketClassSpeedIncrement[MAX_ROCKET_CLASSES];
float g_fRocketClassTurnRate[MAX_ROCKET_CLASSES];
float g_fRocketClassTurnRateIncrement[MAX_ROCKET_CLASSES];
float g_fRocketClassElevationRate[MAX_ROCKET_CLASSES];
float g_fRocketClassElevationLimit[MAX_ROCKET_CLASSES];
float g_fRocketClassRocketsModifier[MAX_ROCKET_CLASSES];
float g_fRocketClassPlayerModifier[MAX_ROCKET_CLASSES];
float g_fRocketClassControlDelay[MAX_ROCKET_CLASSES];
float g_fRocketClassTargetWeight[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnSpawn[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnDeflect[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnKill[MAX_ROCKET_CLASSES];
Handle g_hRocketClassCmdsOnExplode[MAX_ROCKET_CLASSES];
Handle g_hRocketClassTrie;
char g_iRocketClassCount;

// Spawner classes
char g_strSpawnersName[MAX_SPAWNER_CLASSES][32];
int g_iSpawnersMaxRockets[MAX_SPAWNER_CLASSES];
float g_fSpawnersInterval[MAX_SPAWNER_CLASSES];
Handle g_hSpawnersChancesTable[MAX_SPAWNER_CLASSES];
Handle g_hSpawnersTrie;
int g_iSpawnersCount;

// Array containing the spawn points for the Red team, and
// their associated spawner class.
int g_iCurrentRedSpawn;
int g_iSpawnPointsRedCount;
int g_iSpawnPointsRedClass[MAX_SPAWN_POINTS];
int g_iSpawnPointsRedEntity[MAX_SPAWN_POINTS];

// Array containing the spawn points for the Blu team, and
// their associated spawner class.
int g_iCurrentBluSpawn;
int g_iSpawnPointsBluCount;
int g_iSpawnPointsBluClass[MAX_SPAWN_POINTS];
int g_iSpawnPointsBluEntity[MAX_SPAWN_POINTS];

// The default spawner class.
int g_defaultRedSpawner;
int g_defaultBluSpawner;

//Observer
int g_observer;
int g_op_rocket;



public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_NAME, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_CONTACT
};


//
// PD.7 #PLUGIN START/END
//
public void OnPluginStart() {
	// Check if the game is Team Fortress 2
	if (!GameIsTF2())
		SetFailState("This plugin is only for Team Fortress 2.");
	
	// Register Commands
	RegConsoleCmd("sm_currentrocket", CurrentRocketCommand, "Posts a chat message of the name of the current main rocket class.");
	RegConsoleCmd("sm_ab", AirBlastCommand);
	RegServerCmd("sakadb_explosion", ExplosionCommand);
	RegServerCmd("sakadb_shockwave", ShockWaveCommand);
	RegServerCmd("sakadb_resize", ResizeCommand);
	RegAdminCmd("sm_tfdb", AdminMenuCommand, ADMFLAG_GENERIC, "A menu for admins to modify things inside the plugin.");
	ServerCommand("tf_arena_use_queue 0");
	//Create CVARS
	createConvars();
	
	// Check ConVarChange
	HookConVarChange(CVAR_MaxRocketBounces, tf2dodgeball_hooks);
	HookConVarChange(CVAR_AutoPyroVision, tf2dodgeball_hooks);
	
	g_hRocketClassTrie = CreateTrie();
	g_hSpawnersTrie = CreateTrie();
	g_hud = CreateHudSynchronizer();
	
	// Create Config
	
}








//
// PD.8 #COMMANDS
//
// PD.8:1 #ADMINMENU COMMAND
public Action AdminMenuCommand(int client, int args) {
	DrawAdminMenu(client);
	return Plugin_Handled;
}

void DrawAdminMenu(int client) {
	Menu menu = new Menu(AdminMenuHandler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("Dodgeball Admin Menu");
	menu.AddItem("0", "Max Rocket Count");
	menu.AddItem("1", "Speed Multiplier");
	menu.AddItem("2", "Main Rocket Class");
	menu.AddItem("4", "Refresh Configurations");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
public int AdminMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Start: {
			// It's important to log anything in any way, the best is printtoserver, but if you just want to log to client to make it easier to get progress done, feel free.
			PrintToServer("Displaying menu"); // Log it
		}
		case MenuAction_Display: {
			PrintToServer("Client %d was sent menu with panel %x", client, param2); // Log so you can check if it gets sent.
		}
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			switch (param2) {
				case 0:
				DrawMaxRocketCountMenu(client);
				case 1:
				DrawRocketSpeedMenu(client);
				case 2: {
					if (!g_strSavedClassName[0]) {
						CPrintToChat(client, "{mediumpurple}ᴅʙ {black}» {default}No main rocket class detected, aborting...");
						return;
					}
					DrawRocketClassMenu(client);
				}
				case 3: {
					DestroyRocketClasses();
					DestroySpawners();
					char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
					char strMapFile[PLATFORM_MAX_PATH]; Format(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
					ParseConfigurations();
					ParseConfigurations(strMapFile);
					CPrintToChat(client, "{mediumpurple}ᴅʙ {black}» {default}You refreshed the Dodgeball configs.");
				}
			}
		}
		case MenuAction_Cancel:
		PrintToServer("Client %d's menu was cancelled for reason %d", client, param2); // Logging once again.
		case MenuAction_End:
		delete menu;
		case MenuAction_DrawItem: {
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}
		
		case MenuAction_DisplayItem: {
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
}



void DrawMaxRocketCountMenu(int client) {
	Menu menu = new Menu(MaxRocketCountMenuHandler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("How many rockets?");
	menu.AddItem("1", "One");
	menu.AddItem("2", "Two");
	menu.AddItem("3", "Three");
	menu.AddItem("4", "Four");
	menu.AddItem("5", "Five");
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
public int MaxRocketCountMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Start:
		PrintToServer("Displaying menu"); // Log it
		case MenuAction_Display:
		PrintToServer("Client %d was sent menu with panel %x", param1, param2); // Log so you can check if it gets sent.
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			
			switch (param2) {
				case 0: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassBlu] = 1;
					
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassRed] = 1;
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}1{default}.", param1);
				}
				case 1: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassBlu] = 2;
					
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassRed] = 2;
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}2{default}.", param1);
				}
				case 2: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassBlu] = 3;
					
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassRed] = 3;
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}3{default}.", param1);
				}
				case 3: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassBlu] = 4;
					
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassRed] = 4;
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}4{default}.", param1);
				}
				case 4: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassBlu] = 5;
					
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					g_iSpawnersMaxRockets[iSpawnerClassRed] = 5;
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}5{default}.", param1);
				}
			}
		}
		case MenuAction_Cancel: {
			delete menu;
			if (param2 == MenuCancel_ExitBack)
				DrawAdminMenu(param1);
		}
		case MenuAction_End:
		delete menu;
		case MenuAction_DrawItem: {
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}
		
		case MenuAction_DisplayItem: {
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
}

void DrawRocketSpeedMenu(int client) {
	Menu menu = new Menu(RocketSpeedMenuHandler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("How fast should the rockets go?");
	
	menu.AddItem("1", "50% (Slow)");
	menu.AddItem("2", "100% (Normal)");
	menu.AddItem("3", "200% (Fast)");
	menu.AddItem("4", "300% (Silly Fast)");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
public int RocketSpeedMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Start:
		PrintToServer("Displaying menu"); // Log it
		case MenuAction_Display:
		PrintToServer("Client %d was sent menu with panel %x", param1, param2); // Log so you can check if it gets sent.
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			float kvSpeed = g_fSavedSpeed;
			//float kvSpeedIncrement = g_fSavedSpeedIncrement;
			
			switch (param2) {
				case 0: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					int iClassRed = GetRandomRocketClass(iSpawnerClassRed);
					int iClassBlu = GetRandomRocketClass(iSpawnerClassBlu);
					g_fRocketSpeed[iClassRed] = kvSpeed / 2;
					//g_fRocketClassSpeedIncrement[iClassRed] = kvSpeedIncrement / 2;
					g_fRocketSpeed[iClassBlu] = kvSpeed / 2;
					//g_fRocketClassSpeedIncrement[iClassBlu] = kvSpeedIncrement / 2;
					CPrintToChatAll("{mediumpurple}%N{default} changed the rocket speed to{dodgerblue} 50%%{default} (Slow)", param1);
				}
				case 1: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					int iClassRed = GetRandomRocketClass(iSpawnerClassRed);
					int iClassBlu = GetRandomRocketClass(iSpawnerClassBlu);
					g_fRocketSpeed[iClassRed] = kvSpeed;
					//g_fRocketClassSpeedIncrement[iClassRed] = kvSpeedIncrement;
					g_fRocketSpeed[iClassBlu] = kvSpeed;
					//g_fRocketClassSpeedIncrement[iClassBlu] = kvSpeedIncrement;
					CPrintToChatAll("{mediumpurple}%N{default} changed the rocket speed to {dodgerblue}100%%{default} (Normal)", param1);
				}
				case 2: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					int iClassRed = GetRandomRocketClass(iSpawnerClassRed);
					int iClassBlu = GetRandomRocketClass(iSpawnerClassBlu);
					g_fRocketSpeed[iClassRed] = kvSpeed * 2;
					//g_fRocketClassSpeedIncrement[iClassRed] = kvSpeedIncrement * 2;
					g_fRocketSpeed[iClassBlu] = kvSpeed * 2;
					//g_fRocketClassSpeedIncrement[iClassBlu] = kvSpeedIncrement * 2;
					CPrintToChatAll("{mediumpurple}%N{default} changed the rocket speed to {dodgerblue} 200%%{default} (Fast)", param1);
					
				}
				case 3: {
					int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
					int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
					int iClassRed = GetRandomRocketClass(iSpawnerClassRed);
					int iClassBlu = GetRandomRocketClass(iSpawnerClassBlu);
					g_fRocketSpeed[iClassRed] = kvSpeed * 3;
					//g_fRocketClassSpeedIncrement[iClassRed] = kvSpeedIncrement * 3;
					g_fRocketSpeed[iClassBlu] = kvSpeed * 3;
					//g_fRocketClassSpeedIncrement[iClassBlu] = kvSpeedIncrement * 3;
					CPrintToChatAll("{mediumpurple}%N {default} changed the rocket speed to {dodgerblue}300%%{default} (Silly Fast)", param1);
				}
			}
		}
		case MenuAction_Cancel: {
			delete menu;
			if (param2 == MenuCancel_ExitBack)
				DrawAdminMenu(param1);
		}
		case MenuAction_End:
		delete menu;
		case MenuAction_DrawItem: {
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}
		case MenuAction_DisplayItem: {
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
}

void DrawRocketClassMenu(int client) {
	Menu menu = new Menu(RocketClassMenuHandler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("Which class should the rocket be set to?");
	
	for (int currentClass = 0; currentClass < g_iRocketClassCount; currentClass++) {
		char classNumber[16];
		IntToString(currentClass, classNumber, sizeof(classNumber));
		if (StrEqual(g_strSavedClassName, g_strRocketClassLongName[currentClass]))
		{
			char currentClassName[32];
			strcopy(currentClassName, sizeof(currentClassName), "[Current] ");
			StrCat(currentClassName, sizeof(currentClassName), g_strSavedClassName);
			menu.AddItem(classNumber, currentClassName);
		}
		else menu.AddItem(classNumber, g_strRocketClassLongName[currentClass]);
	}
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
public int RocketClassMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action)
	{
		case MenuAction_Start:
		{
			// It's important to log anything in any way, the best is printtoserver, but if you just want to log to client to make it easier to get progress done, feel free.
			PrintToServer("Displaying menu"); // Log it
		}
		
		case MenuAction_Display:
		{
			PrintToServer("Client %d was sent menu with panel %x", param1, param2); // Log so you can check if it gets sent.
		}
		
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			
			SetMainRocketClass(param2, param1);
		}
		
		case MenuAction_Cancel:
		{
			delete menu;
			if (param2 == MenuCancel_ExitBack)
				DrawAdminMenu(param1);
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
}


void createConvars() {
	CreateConVar("sakadb_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY | FCVAR_UNLOGGED | FCVAR_DONTRECORD | FCVAR_REPLICATED | FCVAR_NOTIFY);
	CVAR_Enabled = CreateConVar("sakadb_enabled", "1", "Enable Dodgeball on TFDB maps?", _, true, 0.0, true, 1.0);
	CVAR_EnableCfgFile = CreateConVar("sakadb_enablecfg", "sourcemod/dodgeball_enable.cfg", "Config file to execute when enabling the Dodgeball game mode.");
	CVAR_DisableCfgFile = CreateConVar("sakadb_disablecfg", "sourcemod/dodgeball_disable.cfg", "Config file to execute when disabling the Dodgeball game mode.");
	CVAR_HudSpeedo = CreateConVar("sakadb_hudspeedo", "1", "Enable HUD speedometer");
	CVAR_KillAnnounce = CreateConVar("sakadb_killannounce", "1", "Enable kill announces in chat");
	CVAR_AutoPyroVision = CreateConVar("sakadb_autopyrovision", "0", "Enable pyrovision for everyone");
	CVAR_MaxRocketBounces = CreateConVar("sakadb_maxrocketbounce", "10000", "Max number of times a rocket will bounce.", FCVAR_NONE, true, 0.0, false);
	CVAR_AirBlastCMD = CreateConVar("sakadb_airblastcmd", "1", "Enable if airblast is enabled or not");
	CVAR_DeflectCountAnnounce = CreateConVar("sakadb_deflectcount_announce", "1", "Enable number of deflections in kill announce");
	CVAR_RedirectBeep = CreateConVar("sakadb_redirectbeep", "1", "Do redirects beep?");
	CVAR_PreventTauntKills = CreateConVar("sakadb_block_tauntkill", "0", "Block taunt kills?");
	CVAR_StealPrevention = CreateConVar("sakadb_steal_prevention", "0", "Enable steal prevention?");
	CVAR_StealPreventionCount = CreateConVar("sakadb_sp_count", "3", "How many steals before you get slayed?");
	CVAR_DelayPrevention = CreateConVar("sakadb_delay_prevention", "0", "Enable delay prevention?");
	CVAR_DelayPreventionTime = CreateConVar("sakadb_dp_time", "5", "How much time (in seconds) before delay prevention activates?", FCVAR_NONE, true, 0.0, false);
	CVAR_DelayPreventionSpeedup = CreateConVar("sakadb_dp_speedup", "100", "How much speed (in hammer units per second) should the rocket gain (20 Refresh Rate for every 0.1 seconds) for delay prevention? Multiply by (15/352) for mph.", FCVAR_NONE, true, 0.0, false);
}
// PD.8:2 #AIRBLAST COMMAND
public Action AirBlastCommand(int clientId, int args) {
	if (!g_mapIsTFDB)
		return Plugin_Handled;
	
	if (GetConVarBool(CVAR_AirBlastCMD)) {
		char arg[128];
		
		if (args > 1) {
			CReplyToCommand(clientId, "{mediumpurple}ᴅʙ {black}» {default}Usage: /ab <1|0>");
			return Plugin_Handled;
		}
		
		if (args == 0) {
			preventAirblast(clientId, !PVAR_AIRBLAST_PREVENTION[clientId]);
		} else if (args == 1) {
			GetCmdArg(1, arg, sizeof(arg));
			
			if (strcmp(arg, "0") == 0) {
				preventAirblast(clientId, false);
			} else if (strcmp(arg, "1") == 0) {
				preventAirblast(clientId, true);
			} else {
				CReplyToCommand(clientId, "{mediumpurple}ᴅʙ {black}» {default}Usage: /ab <1|0>");
				return Plugin_Handled;
			}
		}
		
		if (PVAR_AIRBLAST_PREVENTION[clientId]) {
			CReplyToCommand(clientId, "{mediumpurple}ᴅʙ {black}» {default}Airblast Prevention Enabled");
		} else {
			CReplyToCommand(clientId, "{mediumpurple}ᴅʙ {black}» {default}Airblast Prevention Disabled");
		}
		return Plugin_Handled;
	}
	if (!GetConVarBool(CVAR_AirBlastCMD)) {
		CReplyToCommand(clientId, "{mediumpurple}ᴅʙ {black}» {default}Airblast Prevention is disabled on this server.");
		preventAirblast(clientId, false);
	}
	return Plugin_Handled;
}

// PD.8:3 #CURRENTROCKET COMMAND
public Action CurrentRocketCommand(int client, int args) {
	if (args > 1) {
		CReplyToCommand(client, "{mediumpurple}ᴅʙ {black}» {default}Usage: /currentrocket");
		return Plugin_Handled;
	}
	
	if (!g_strSavedClassName[0]) {
		CPrintToChat(client, "{mediumpurple}ᴅʙ {black}» {default}Current Rocket: {dodgerblue}Multiple{default}");
		return Plugin_Handled;
	}
	CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {default}Current Rocket: {dodgerblue}%s{default}", g_strSavedClassName);
	
	return Plugin_Handled;
}

// PD.8:4 #SHOCKWAVE COMMAND
public Action ShockWaveCommand(int iArgs) {
	if (!g_pluginEnabled || !g_mapIsTFDB) {
		PrintToServer("Cannot use command. Dodgeball is disabled.");
		return Plugin_Handled;
	}
	if (iArgs == 5) {
		char strBuffer[8];
		int iClient;
		int iTeam;
		float fPosition[3];
		int iDamage;
		float fPushStrength;
		float fRadius;
		float fFalloffRadius;
		GetCmdArg(1, strBuffer, sizeof(strBuffer)); iClient = StringToInt(strBuffer);
		GetCmdArg(2, strBuffer, sizeof(strBuffer)); iDamage = StringToInt(strBuffer);
		GetCmdArg(3, strBuffer, sizeof(strBuffer)); fPushStrength = StringToFloat(strBuffer);
		GetCmdArg(4, strBuffer, sizeof(strBuffer)); fRadius = StringToFloat(strBuffer);
		GetCmdArg(5, strBuffer, sizeof(strBuffer)); fFalloffRadius = StringToFloat(strBuffer);
		if (IsValidClient(iClient)) {
			iTeam = GetClientTeam(iClient);
			GetClientAbsOrigin(iClient, fPosition);
			for (iClient = 1; iClient <= MaxClients; iClient++) {
				if ((IsValidClient(iClient, true) == true) && (GetClientTeam(iClient) == iTeam)) {
					float fPlayerPosition[3]; GetClientEyePosition(iClient, fPlayerPosition);
					float fDistanceToShockwave = GetVectorDistance(fPosition, fPlayerPosition);
					
					if (fDistanceToShockwave < fRadius) {
						float fImpulse[3];
						float fFinalPush;
						int iFinalDamage;
						fImpulse[0] = fPlayerPosition[0] - fPosition[0];
						fImpulse[1] = fPlayerPosition[1] - fPosition[1];
						fImpulse[2] = fPlayerPosition[2] - fPosition[2];
						NormalizeVector(fImpulse, fImpulse);
						if (fImpulse[2] < 0.4) { fImpulse[2] = 0.4; NormalizeVector(fImpulse, fImpulse); }
						
						if (fDistanceToShockwave < fFalloffRadius) {
							fFinalPush = fPushStrength;
							iFinalDamage = iDamage;
						} else {
							float fImpact = (1.0 - ((fDistanceToShockwave - fFalloffRadius) / (fRadius - fFalloffRadius)));
							fFinalPush = fImpact * fPushStrength;
							iFinalDamage = RoundToFloor(fImpact * iDamage);
						}
						ScaleVector(fImpulse, fFinalPush);
						SetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fImpulse);
						
						Handle hDamage = CreateDataPack();
						WritePackCell(hDamage, iClient);
						WritePackCell(hDamage, iFinalDamage);
						CreateTimer(0.1, ApplyDamage, hDamage, TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
		}
	} else {
		PrintToServer("Usage: sakadb_shockwave <client index> <damage> <push strength> <radius> <falloff>");
	}
	
	return Plugin_Handled;
}

// PD.8:5 #EXPLOSION COMMAND
public Action ExplosionCommand(int iArgs) {
	if (!g_pluginEnabled || !g_mapIsTFDB) {
		PrintToServer("Cannot use command. Dodgeball is disabled.");
		return Plugin_Handled;
	}
	
	if (iArgs == 1) {
		char strBuffer[8], iClient;
		GetCmdArg(1, strBuffer, sizeof(strBuffer));
		iClient = StringToInt(strBuffer);
		if (IsValidEntity(iClient)) {
			float fPosition[3];
			GetClientAbsOrigin(iClient, fPosition);
			switch (GetURandomIntRange(0, 4)) {
				case 0:
				PlayParticle(fPosition, PARTICLE_NUKE_1_ANGLES, PARTICLE_NUKE_1);
				case 1:
				PlayParticle(fPosition, PARTICLE_NUKE_2_ANGLES, PARTICLE_NUKE_2);
				case 2:
				PlayParticle(fPosition, PARTICLE_NUKE_3_ANGLES, PARTICLE_NUKE_3);
				case 3:
				PlayParticle(fPosition, PARTICLE_NUKE_4_ANGLES, PARTICLE_NUKE_4);
				case 4:
				PlayParticle(fPosition, PARTICLE_NUKE_5_ANGLES, PARTICLE_NUKE_5);
			}
			PlayParticle(fPosition, PARTICLE_NUKE_COLLUMN_ANGLES, PARTICLE_NUKE_COLLUMN);
		}
	} else {
		PrintToServer("Usage: sakadb_explosion <client index>");
	}
	
	return Plugin_Handled;
}

// PD.8:6 #RESIZE COMMAND
public Action ResizeCommand(int iIndex) {
	if (!g_pluginEnabled || !g_mapIsTFDB) {
		PrintToServer("Cannot use command. Dodgeball is disabled.");
		return Plugin_Handled;
	}
	
	int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
	if (iEntity && IsValidEntity(iEntity) && g_bRocketIsNuke[iEntity]) {
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", (4.0));
	}
	
	return Plugin_Handled;
}

//
// PD.9 #EVENTS
// 
public Action ObjectDeflectedEvent(Handle hEvent, const char[] name, bool dontBroadcast) {
	if (!g_mapIsTFDB)
		return;
	int index = GetEventInt(hEvent, "object_entindex");
	if (GetConVarBool(CVAR_AirBlastCMD)) {
		if ((index >= 1) && (index <= MaxClients)) {
			if (PVAR_AIRBLAST_PREVENTION[index]) {
				float Vel[3];
				TeleportEntity(index, NULL_VECTOR, NULL_VECTOR, Vel); // Stops knockback
				TF2_RemoveCondition(index, TFCond_Dazed); // Stops slowdown
				SetEntPropVector(index, Prop_Send, "m_vecPunchAngle", Vel);
				SetEntPropVector(index, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake
			}
		}
	}
}

public Action PlayerSpawnEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!g_mapIsTFDB)
		return;
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int clientId = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	PVAR_STOLEN_ROCKETS[iClient] = 0;
	if (!IsValidClient(iClient))
		return;
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	if (!(iClass == TFClass_Pyro || iClass == view_as<TFClassType>(TFClass_Unknown))) {
		TF2_SetPlayerClass(iClient, TFClass_Pyro, false, true);
		TF2_RespawnPlayer(iClient);
	}
	for (int i = MaxClients; i; --i) {
		if (IsClientInGame(i) && IsPlayerAlive(i))
			SetEntPropEnt(i, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(i, TFWeaponSlot_Primary));
	}
	if (GetConVarBool(CVAR_AutoPyroVision))
		TF2Attrib_SetByName(iClient, PYROVISION_ATTRIBUTE, 1.0);
	if (GetConVarBool(CVAR_AirBlastCMD)) {
		if (PVAR_FIRST_JOINED[clientId])
			PVAR_AIRBLAST_PREVENTION[clientId] = true;
		preventAirblast(clientId, true);
	}
}

public Action PlayerDeathEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!g_mapIsTFDB || !g_roundStarted)
		return;
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (GetConVarBool(CVAR_AirBlastCMD)) {
		int clientId = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		PVAR_FIRST_JOINED[clientId] = false;
	}
	if (IsValidClient(iVictim)) {
		if (GetConVarBool(CVAR_StealPrevention)) {
			bStealArray[iVictim][stoleRocket] = false;
			bStealArray[iVictim][rocketsStolen] = 0;
		}
		
		g_lastDeadClient = iVictim;
		g_lastDeadTeam = GetClientTeam(iVictim);
		
		int iInflictor = GetEventInt(hEvent, "inflictor_entindex");
		int iIndex = FindRocketByEntity(iInflictor);
		
		if (iIndex != -1) {
			int iClass = g_iRocketClass[iIndex];
			int iTarget = EntRefToEntIndex(g_iRocketTarget[iIndex]);
			int iDeflections = g_iRocketDeflections[iIndex];
			
			float fSpeed = CalculateSpeed(g_fRocketSpeed[iIndex]);
			float aSpeed = g_fRocketSpeed[iIndex];
			
			if (GetConVarBool(CVAR_KillAnnounce)) {
				if (GetConVarBool(CVAR_DeflectCountAnnounce)) {
					if (iVictim == iTarget) {
						CPrintToChatAll("{mediumpurple}%N{default} died to {dodgerblue}%.0f{default} mph ({dodgerblue}%i{default} Deflections | {dodgerblue}%.0f{default} Admin Speed)", g_lastDeadClient, fSpeed, iDeflections, aSpeed);
					} else {
						CPrintToChatAll("{mediumpurple}%N{default} died to {dodgerblue}%.15N's{default} rocket: {mediumpurple}%.0f{default} mph ({dodgerblue}%i{default} Deflections | {dodgerblue}%.0f{default} Admin Speed)", g_lastDeadClient, iTarget, fSpeed, iDeflections, aSpeed);
					}
				} else {
					CPrintToChatAll("{mediumpurple}%N{default} died to {dodgerblue}%.f{default} mph!", g_lastDeadClient, fSpeed);
				}
			}
			
			if ((g_iRocketFlags[iIndex] & RocketFlag_OnExplodeCmd) && !(g_iRocketFlags[iIndex] & RocketFlag_Exploded)) {
				ExecuteCommands(g_hRocketClassCmdsOnExplode[iClass], iClass, iInflictor, iAttacker, iTarget, g_lastDeadClient, fSpeed, iDeflections);
				g_iRocketFlags[iIndex] |= RocketFlag_Exploded;
			}
			
			if (TestFlags(g_iRocketFlags[iIndex], RocketFlag_OnKillCmd))
				ExecuteCommands(g_hRocketClassCmdsOnKill[iClass], iClass, iInflictor, iAttacker, iTarget, g_lastDeadClient, fSpeed, iDeflections);
		}
	}
	SetRandomSeed(view_as<int>(GetGameTime()));
}

public Action OnSetupFinished(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if ((g_pluginEnabled == true && g_mapIsTFDB) && (BothTeamsPlaying() == true)) {
		PopulateSpawnPoints();
		
		if (g_lastDeadTeam == 0)
			g_lastDeadTeam = GetURandomIntRange(view_as<int>(TFTeam_Red), view_as<int>(TFTeam_Blue));
		if (!IsValidClient(g_lastDeadClient))
			g_lastDeadClient = 0;
		
		g_logicTimer = CreateTimer(FPS_LOGIC_INTERVAL, OnDodgeBallGameFrame, _, TIMER_REPEAT);
		g_playerCount = CountAlivePlayers();
		g_rocketsFired = 0;
		g_iCurrentRedSpawn = 0;
		g_iCurrentBluSpawn = 0;
		g_nextSpawnTime = GetGameTime();
		g_roundStarted = true;
		g_roundCount++;
	}
}

public Action OnPlayerInventoryEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!g_mapIsTFDB)
		return;
	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(iClient))return;
	
	for (int iSlot = 1; iSlot < 5; iSlot++) {
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity != -1)RemoveEdict(iEntity);
	}
}

//
// PD.10 #SOURCE MOD EVENTS
// 

/**/

public void OnMapStart() {
	g_mapIsTFDB = IsDodgeballMap();
}

public void OnMapEnd() {
	DisableDodgeBall();
}

public void OnConfigsExecuted() {
	if (GetConVarBool(CVAR_Enabled) == true)
		if (g_mapIsTFDB == true)
			EnableDodgeBall();
}

public void OnClientPutInServer(int clientId) {
	if (!g_mapIsTFDB)
		return;
	if (GetConVarBool(CVAR_AirBlastCMD))
		PVAR_FIRST_JOINED[clientId] = true;
	if (GetConVarBool(CVAR_PreventTauntKills))
		SDKHook(clientId, SDKHook_OnTakeDamage, TauntCheck);
}

public void OnClientDisconnect(int client) {
	if (!g_mapIsTFDB)
		return;
	if (GetConVarBool(CVAR_PreventTauntKills))
		SDKUnhook(client, SDKHook_OnTakeDamage, TauntCheck);
	if (GetConVarBool(CVAR_StealPrevention)) {
		bStealArray[client][stoleRocket] = false;
		bStealArray[client][rocketsStolen] = 0;
	}
}

public Action OnRoundStart(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!g_mapIsTFDB)
		return;
	if (GetConVarBool(CVAR_StealPrevention)) {
		for (int i = 0; i <= MaxClients; i++) {
			bStealArray[i][stoleRocket] = false;
			bStealArray[i][rocketsStolen] = 0;
		}
	}
	
	
	g_lastRocketSpeed = 0;
	if (g_timerHud != INVALID_HANDLE) {
		KillTimer(g_timerHud);
		g_timerHud = INVALID_HANDLE;
	}
	g_timerHud = CreateTimer(1.0, Timer_HudSpeed, _, TIMER_REPEAT);
}

public Action OnRoundEnd(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!g_mapIsTFDB)
		return;
	
	if (g_timerHud != INVALID_HANDLE) {
		KillTimer(g_timerHud);
		g_timerHud = INVALID_HANDLE;
	}
	if (g_logicTimer != INVALID_HANDLE) {
		KillTimer(g_logicTimer);
		g_logicTimer = INVALID_HANDLE;
	}
	
	if (GetConVarBool(CVAR_AirBlastCMD))
		for (int i = 0; i < MAXPLAYERS + 1; i++)
	PVAR_FIRST_JOINED[i] = false;
	
	DestroyRockets();
	g_roundStarted = false;
}
//
// PD.11 #FUNCTIONS
//
bool IsDodgeballMap() {
	char strMap[64];
	GetCurrentMap(strMap, sizeof(strMap));
	return StrContains(strMap, "tfdb_", false) == 0;
}
bool GameIsTF2() {
	char strModName[32]; GetGameFolderName(strModName, sizeof(strModName));
	return StrEqual(strModName, "tf");
}

void EnableDodgeBall() {
	if (g_pluginEnabled == false) {
		// Parse configuration files
		char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
		char strMapFile[PLATFORM_MAX_PATH]; Format(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
		ParseConfigurations();
		ParseConfigurations(strMapFile);
		
		ServerCommand("sakadb_maxrocketbounce %f", GetConVarFloat(CVAR_MaxRocketBounces));
		
		// Check if we have all the required information
		if (g_iRocketClassCount == 0)
			SetFailState("No rocket class defined.");
		
		if (g_iSpawnersCount == 0)
			SetFailState("No spawner class defined.");
		
		if (g_defaultRedSpawner == -1)
			SetFailState("No spawner class definition for the Red spawners exists in the config file.");
		
		if (g_defaultBluSpawner == -1)
			SetFailState("No spawner class definition for the Blu spawners exists in the config file.");
		
		// Hook events and info_target outputs.
		HookEvent("object_deflected", ObjectDeflectedEvent);
		HookEvent("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);
		HookEvent("teamplay_setup_finished", OnSetupFinished, EventHookMode_PostNoCopy);
		HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
		HookEvent("player_spawn", PlayerSpawnEvent, EventHookMode_Post);
		HookEvent("player_death", PlayerDeathEvent, EventHookMode_Pre);
		
		//HookEvent("object_detonated", OnPlayerHurt, EventHookMode_Pre);
		HookEvent("post_inventory_application", OnPlayerInventoryEvent, EventHookMode_Post);
		
		
		
		// Precache sounds
		PrecacheSound(SOUND_DEFAULT_SPAWN, true);
		PrecacheSound(SOUND_DEFAULT_BEEP, true);
		PrecacheSound(SOUND_DEFAULT_ALERT, true);
		PrecacheSound(SOUND_DEFAULT_SPEEDUPALERT, true);
		
		// Precache particles
		PrecacheParticle(PARTICLE_NUKE_1);
		PrecacheParticle(PARTICLE_NUKE_2);
		PrecacheParticle(PARTICLE_NUKE_3);
		PrecacheParticle(PARTICLE_NUKE_4);
		PrecacheParticle(PARTICLE_NUKE_5);
		PrecacheParticle(PARTICLE_NUKE_COLLUMN);
		
		// Precache rocket resources
		for (int i = 0; i < g_iRocketClassCount; i++) {
			RocketFlags iFlags = g_iRocketClassFlags[i];
			if (TestFlags(iFlags, RocketFlag_CustomModel))PrecacheModelEx(g_strRocketClassModel[i], true, true);
			if (TestFlags(iFlags, RocketFlag_CustomSpawnSound))PrecacheSoundEx(g_strRocketClassSpawnSound[i], true, true);
			if (TestFlags(iFlags, RocketFlag_CustomBeepSound))PrecacheSoundEx(g_strRocketClassBeepSound[i], true, true);
			if (TestFlags(iFlags, RocketFlag_CustomAlertSound))PrecacheSoundEx(g_strRocketClassAlertSound[i], true, true);
		}
		
		// Execute enable config file
		char strCfgFile[64]; GetConVarString(CVAR_EnableCfgFile, strCfgFile, sizeof(strCfgFile));
		ServerCommand("exec \"%s\"", strCfgFile);
		
		// Done.
		g_pluginEnabled = true;
		g_roundStarted = false;
		g_roundCount = 0;
	}
}
void DisableDodgeBall() {
	if (g_pluginEnabled == true) {
		// Clean up everything
		DestroyRockets();
		DestroyRocketClasses();
		DestroySpawners();
		if (g_logicTimer != INVALID_HANDLE)
			KillTimer(g_logicTimer);
		g_logicTimer = INVALID_HANDLE;
		UnhookEvent("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_setup_finished", OnSetupFinished, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", PlayerSpawnEvent, EventHookMode_Post);
		UnhookEvent("player_death", PlayerDeathEvent, EventHookMode_Pre);
		UnhookEvent("post_inventory_application", OnPlayerInventoryEvent, EventHookMode_Post);
		char strCfgFile[64]; GetConVarString(CVAR_DisableCfgFile, strCfgFile, sizeof(strCfgFile));
		ServerCommand("exec \"%s\"", strCfgFile);
		g_pluginEnabled = false;
		g_roundStarted = false;
		g_roundCount = 0;
	}
}











/* OnPlayerRunCmd()
**
** Block flamethrower's Mouse1 attack.
** -------------------------------------------------------------------------- */
public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon) {
	if (g_pluginEnabled == true && g_mapIsTFDB)iButtons &= ~IN_ATTACK;
	return Plugin_Continue;
}

/* OnDodgeBallGameFrame()
**
** Every tick of the Dodgeball logic.
** -------------------------------------------------------------------------- */
public Action OnDodgeBallGameFrame(Handle hTimer, any Data) {
	if (!g_mapIsTFDB)
		return;
	
	// Only if both teams are playing
	if (BothTeamsPlaying() == false)
		return;
	
	// Check if we need to fire more rockets.
	if (GetGameTime() >= g_nextSpawnTime) {
		if (g_lastDeadTeam == view_as<int>(TFTeam_Red)) {
			int iSpawnerEntity = g_iSpawnPointsRedEntity[g_iCurrentRedSpawn];
			int iSpawnerClass = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
			if (g_iRocketCount < g_iSpawnersMaxRockets[iSpawnerClass]) {
				//CPrintToChatAll("CREATED ROCKET LAST ROCKET SPEED %i", g_lastRocketSpeed);
				CreateRocket(iSpawnerEntity, iSpawnerClass, view_as<int>(TFTeam_Red));
				g_iCurrentRedSpawn = (g_iCurrentRedSpawn + 1) % g_iSpawnPointsRedCount;
			}
		} else {
			int iSpawnerEntity = g_iSpawnPointsBluEntity[g_iCurrentBluSpawn];
			int iSpawnerClass = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
			if (g_iRocketCount < g_iSpawnersMaxRockets[iSpawnerClass]) {
				//CPrintToChatAll("CREATED ROCKET LAST ROCKET SPEED %i", g_lastRocketSpeed);
				CreateRocket(iSpawnerEntity, iSpawnerClass, view_as<int>(TFTeam_Blue));
				g_iCurrentBluSpawn = (g_iCurrentBluSpawn + 1) % g_iSpawnPointsBluCount;
				
			}
		}
	}
	
	// Manage the active rockets
	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1) {
		switch (g_iRocketClassBehaviour[g_iRocketClass[iIndex]]) {
			case Behaviour_Unknown: {  }
			case Behaviour_Homing: { HomingRocketThink(iIndex); }
		}
	}
}

/*public Action ShowToTarget(int iIndex, int iClient)
{
	int iParticle = EntRefToEntIndex(g_RocketParticle[iIndex]);
	int iTarget = EntRefToEntIndex(g_iRocketTarget[iIndex]);

	if (!IsValidEntity(iParticle))
		return Plugin_Handled;

	if (!IsValidClient(iTarget))
		return Plugin_Handled;

	if (iClient != iTarget)
		return Plugin_Handled;

	return Plugin_Continue;
}*/

public Action Timer_HudSpeed(Handle hTimer) {
	if (GetConVarBool(CVAR_HudSpeedo) && g_mapIsTFDB) {
		SetHudTextParams(-1.0, 0.9, 1.1, 255, 255, 255, 255);
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidClient(iClient) && !IsFakeClient(iClient) && g_lastRocketSpeed != 0)
			ShowSyncHudText(iClient, g_hud, "Speed: %i mph", g_lastRocketSpeed);
	}
}


//	___			_		_
// | _ \___  __| |_____| |_ ___
// |   / _ \/ _| / / -_)  _(_-<
// |_|_\___/\__|_\_\___|\__/__/

/* CreateRocket()
**
** Fires a new rocket entity from the spawner's position.
** -------------------------------------------------------------------------- */
public void CreateRocket(int iSpawnerEntity, int iSpawnerClass, int iTeam) {
	int iIndex = FindFreeRocketSlot();
	if (iIndex != -1) {
		// Fetch a random rocket class and it's parameters.
		int iClass = GetRandomRocketClass(iSpawnerClass);
		RocketFlags iFlags = g_iRocketClassFlags[iClass];
		
		// Create rocket entity.
		int iEntity = CreateEntityByName(TestFlags(iFlags, RocketFlag_IsAnimated) ? "tf_projectile_sentryrocket" : "tf_projectile_rocket");
		if (iEntity && IsValidEntity(iEntity)) {
			// Fetch spawn point's location and angles.
			float fPosition[3];
			float fAngles[3];
			float fDirection[3];
			GetEntPropVector(iSpawnerEntity, Prop_Send, "m_vecOrigin", fPosition);
			GetEntPropVector(iSpawnerEntity, Prop_Send, "m_angRotation", fAngles);
			GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
			
			// Setup rocket entity.
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", 0);
			SetEntProp(iEntity, Prop_Send, "m_bCritical", (GetURandomFloatRange(0.0, 100.0) <= g_fRocketClassCritChance[iClass]) ? 1 : 0, 1);
			SetEntProp(iEntity, Prop_Send, "m_iTeamNum", iTeam, 1);
			SetEntProp(iEntity, Prop_Send, "m_iDeflected", 1);
			TeleportEntity(iEntity, fPosition, fAngles, view_as<float>( { 0.0, 0.0, 0.0 } ));
			
			// Setup rocket structure with the newly created entity.
			int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
			int iTarget = SelectTarget(iTargetTeam);
			float fModifier = CalculateModifier(iClass, 0);
			g_bRocketIsValid[iIndex] = true;
			g_iRocketFlags[iIndex] = iFlags;
			g_iRocketEntity[iIndex] = EntIndexToEntRef(iEntity);
			g_iRocketTarget[iIndex] = EntIndexToEntRef(iTarget);
			g_iRocketSpawner[iIndex] = iSpawnerClass;
			g_iRocketClass[iIndex] = iClass;
			g_iRocketDeflections[iIndex] = 0;
			g_fRocketLastDeflectionTime[iIndex] = GetGameTime();
			g_fRocketLastBeepTime[iIndex] = GetGameTime();
			g_fRocketSpeed[iIndex] = CalculateRocketSpeed(iClass, fModifier);
			g_lastRocketSpeed = RoundFloat(g_fRocketSpeed[iIndex] * 0.042614);
			
			CopyVectors(fDirection, g_fRocketDirection[iIndex]);
			SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(iClass, fModifier), true);
			DispatchSpawn(iEntity);
			
			// Apply custom model, if specified on the flags.
			if (TestFlags(iFlags, RocketFlag_CustomModel))
			{
				SetEntityModel(iEntity, g_strRocketClassModel[iClass]);
				UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
			}
			
			// Execute commands on spawn.
			if (TestFlags(iFlags, RocketFlag_OnSpawnCmd))
			{
				ExecuteCommands(g_hRocketClassCmdsOnSpawn[iClass], iClass, iEntity, 0, iTarget, g_lastDeadClient, g_fRocketSpeed[iIndex], 0);
			}
			
			// Emit required sounds.
			EmitRocketSound(RocketSound_Spawn, iClass, iEntity, iTarget, iFlags);
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
			
			// Done
			g_iRocketCount++;
			g_rocketsFired++;
			g_lastSpawnTime = GetGameTime();
			g_nextSpawnTime = GetGameTime() + g_fSpawnersInterval[iSpawnerClass];
			g_bRocketIsNuke[iIndex] = false;
			
			//AttachParticle(iEntity, "burningplayer_rainbow_glow");
			//AttachParticle(iEntity, "burningplayer_rainbow_glow_old");
			//CreateTempParticle("superrare_greenenergy", iEntity, _, _, true);
			//SDKHook(iEntity, SDKHook_SetTransmit, ShowToTarget);
			
			//Observer
			if (IsValidEntity(g_observer))
			{
				g_op_rocket = iEntity;
				TeleportEntity(g_observer, fPosition, fAngles, view_as<float>( { 0.0, 0.0, 0.0 } ));
				SetVariantString("!activator");
				AcceptEntityInput(g_observer, "SetParent", g_op_rocket);
			}
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	
	if (!g_mapIsTFDB)
		return;
	
	if (entity == -1) {
		return;
	}
	if (IsValidRocket(FindRocketByEntity(entity)) && g_lastRocketSpeed >= 35) {
		
		int iTarget = EntRefToEntIndex(g_iRocketTarget[FindRocketByEntity(entity)]);
		CPrintToChatAll("test MPH %i ADMINSPEED %.0f ENTITY %i TARGET %N", g_lastRocketSpeed, g_fRocketSpeed, entity, iTarget);
	}
	
	if (entity == g_op_rocket && g_pluginEnabled == true && IsValidEntity(g_observer) && IsValidEntity(g_op_rocket)) {
		CPrintToChatAll("test #2  %i", g_lastRocketSpeed);
		SetVariantString("");
		AcceptEntityInput(g_observer, "ClearParent");
		g_op_rocket = -1;
		
		float opPos[3];
		float opAng[3];
		
		int spawner = GetRandomInt(0, 1);
		if (spawner == 0)
			spawner = g_iSpawnPointsRedEntity[0];
		else
			spawner = g_iSpawnPointsBluEntity[0];
		
		if (IsValidEntity(spawner) && spawner > MAXPLAYERS)
		{
			GetEntPropVector(spawner, Prop_Data, "m_vecOrigin", opPos);
			GetEntPropVector(spawner, Prop_Data, "m_angAbsRotation", opAng);
			TeleportEntity(g_observer, opPos, opAng, NULL_VECTOR);
		}
	}
}

/* DestroyRocket()
**
** Destroys the rocket at the given index.
** -------------------------------------------------------------------------- */
void DestroyRocket(int iIndex)
{
	if (IsValidRocket(iIndex) == true)
	{
		int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
		if (iEntity && IsValidEntity(iEntity))RemoveEdict(iEntity);
		g_bRocketIsValid[iIndex] = false;
		g_iRocketCount--;
	}
}

/* DestroyRockets()
**
** Destroys all the rockets that are currently active.
** -------------------------------------------------------------------------- */
void DestroyRockets()
{
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++)
	{
		DestroyRocket(iIndex);
	}
	g_iRocketCount = 0;
}

/* IsValidRocket()
**
** Checks if a rocket structure is valid.
** -------------------------------------------------------------------------- */
bool IsValidRocket(int iIndex)
{
	if ((iIndex >= 0) && (g_bRocketIsValid[iIndex] == true))
	{
		if (EntRefToEntIndex(g_iRocketEntity[iIndex]) == -1)
		{
			g_bRocketIsValid[iIndex] = false;
			g_iRocketCount--;
			return false;
		}
		return true;
	}
	return false;
}

/* FindNextValidRocket()
**
** Retrieves the index of the next valid rocket from the current offset.
** -------------------------------------------------------------------------- */
int FindNextValidRocket(int iIndex, bool bWrap = false)
{
	for (int iCurrent = iIndex + 1; iCurrent < MAX_ROCKETS; iCurrent++)
	if (IsValidRocket(iCurrent))
		return iCurrent;
	
	return (bWrap == true) ? FindNextValidRocket(-1, false) : -1;
}

/* FindFreeRocketSlot()
**
** Retrieves the next free rocket slot since the current one. If all of them
** are full, returns -1.
** -------------------------------------------------------------------------- */
int FindFreeRocketSlot()
{
	int iIndex = g_iLastCreatedRocket;
	int iCurrent = iIndex;
	
	do
	{
		if (!IsValidRocket(iCurrent))return iCurrent;
		if ((++iCurrent) == MAX_ROCKETS)iCurrent = 0;
	} while (iCurrent != iIndex);
	
	return -1;
}

/* FindRocketByEntity()
**
** Finds a rocket index from it's entity.
** -------------------------------------------------------------------------- */
int FindRocketByEntity(int iEntity)
{
	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1)
		if (EntRefToEntIndex(g_iRocketEntity[iIndex]) == iEntity)
		return iIndex;
	
	return -1;
}

/* HomingRocketThinkg()
**
** Logic process for the Behaviour_Homing type rockets, wich is simply a
** follower rocket, picking a random target.
** -------------------------------------------------------------------------- */
void HomingRocketThink(int iIndex)
{
	// Retrieve the rocket's attributes.
	int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
	int iClass = g_iRocketClass[iIndex];
	RocketFlags iFlags = g_iRocketFlags[iIndex];
	int iTarget = EntRefToEntIndex(g_iRocketTarget[iIndex]);
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iDeflectionCount = GetEntProp(iEntity, Prop_Send, "m_iDeflected") - 1;
	float fModifier = CalculateModifier(iClass, iDeflectionCount);
	
	// Check if the target is available
	if (!IsValidClient(iTarget, true))
	{
		iTarget = SelectTarget(iTargetTeam);
		if (!IsValidClient(iTarget, true))return;
		g_iRocketTarget[iIndex] = EntIndexToEntRef(iTarget);
		
		if (GetConVarBool(CVAR_RedirectBeep))
		{
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		}
	}
	// Has the rocket been deflected recently? If so, set new target.
	else if ((iDeflectionCount > g_iRocketDeflections[iIndex]))
	{
		// Calculate new direction from the player's forward
		int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(iClient))
		{
			float fViewAngles[3];
			float fDirection[3];
			GetClientEyeAngles(iClient, fViewAngles);
			GetAngleVectors(fViewAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
			CopyVectors(fDirection, g_fRocketDirection[iIndex]);
			UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
			if (GetConVarBool(CVAR_StealPrevention))
			{
				checkStolenRocket(iClient, iIndex);
			}
		}
		
		// Set new target & deflection count
		iTarget = SelectTarget(iTargetTeam, iIndex);
		g_iRocketTarget[iIndex] = EntIndexToEntRef(iTarget);
		g_iRocketDeflections[iIndex] = iDeflectionCount;
		g_fRocketLastDeflectionTime[iIndex] = GetGameTime();
		g_fRocketSpeed[iIndex] = CalculateRocketSpeed(iClass, fModifier);
		g_lastRocketSpeed = RoundFloat(g_fRocketSpeed[iIndex] * 0.042614);
		
		g_bPreventingDelay = false;
		
		
		SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(iClass, fModifier), true);
		if (TestFlags(iFlags, RocketFlag_ElevateOnDeflect))g_iRocketFlags[iIndex] |= RocketFlag_Elevating;
		EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		//Send out temp entity to target
		//SendTempEnt(iTarget, "superrare_greenenergy", iEntity, _, _, true);
		
		// Execute appropiate command
		if (TestFlags(iFlags, RocketFlag_OnDeflectCmd))
		{
			ExecuteCommands(g_hRocketClassCmdsOnDeflect[iClass], iClass, iEntity, iClient, iTarget, g_lastDeadClient, g_fRocketSpeed[iIndex], iDeflectionCount);
		}
	}
	else
	{
		// If the delay time since the last reflection has been elapsed, rotate towards the client.
		if ((GetGameTime() - g_fRocketLastDeflectionTime[iIndex]) >= g_fRocketClassControlDelay[iClass])
		{
			// Calculate turn rate and retrieve directions.
			float fTurnRate = CalculateRocketTurnRate(iClass, fModifier);
			float fDirectionToTarget[3]; CalculateDirectionToClient(iEntity, iTarget, fDirectionToTarget);
			
			// Elevate the rocket after a deflection (if it's enabled on the class definition, of course.)
			if (g_iRocketFlags[iIndex] & RocketFlag_Elevating)
			{
				if (g_fRocketDirection[iIndex][2] < g_fRocketClassElevationLimit[iClass])
				{
					g_fRocketDirection[iIndex][2] = FMin(g_fRocketDirection[iIndex][2] + g_fRocketClassElevationRate[iClass], g_fRocketClassElevationLimit[iClass]);
					fDirectionToTarget[2] = g_fRocketDirection[iIndex][2];
				}
				else
				{
					g_iRocketFlags[iIndex] &= ~RocketFlag_Elevating;
				}
			}
			
			// Smoothly change the orientation to the new one.
			LerpVectors(g_fRocketDirection[iIndex], fDirectionToTarget, g_fRocketDirection[iIndex], fTurnRate);
		}
		
		// If it's a nuke, beep every some time
		if ((GetGameTime() - g_fRocketLastBeepTime[iIndex]) >= g_fRocketClassBeepInterval[iClass])
		{
			g_bRocketIsNuke[iIndex] = true;
			EmitRocketSound(RocketSound_Beep, iClass, iEntity, iTarget, iFlags);
			g_fRocketLastBeepTime[iIndex] = GetGameTime();
		}
		
		if (GetConVarBool(CVAR_DelayPrevention))
		{
			checkRoundDelays(iIndex);
		}
	}
	
	// Done
	ApplyRocketParameters(iIndex);
}

/* CalculateModifier()
**
** Gets the modifier for the damage/speed/rotation calculations.
** -------------------------------------------------------------------------- */
float CalculateModifier(int iClass, int iDeflections)
{
	return iDeflections + 
	(g_rocketsFired * g_fRocketClassRocketsModifier[iClass]) + 
	(g_playerCount * g_fRocketClassPlayerModifier[iClass]);
}

/* CalculateRocketDamage()
**
** Calculates the damage of the rocket based on it's type and deflection count.
** -------------------------------------------------------------------------- */
float CalculateRocketDamage(int iClass, float fModifier)
{
	return g_fRocketClassDamage[iClass] + g_fRocketClassDamageIncrement[iClass] * fModifier;
}

/* CalculateRocketSpeed()
**
** Calculates the speed of the rocket based on it's type and deflection count.
** -------------------------------------------------------------------------- */
float CalculateRocketSpeed(int iClass, float fModifier)
{
	return g_fRocketClassSpeed[iClass] + g_fRocketClassSpeedIncrement[iClass] * fModifier;
}

/* CalculateRocketTurnRate()
**
** Calculates the rocket's turn rate based upon it's type and deflection count.
** -------------------------------------------------------------------------- */
float CalculateRocketTurnRate(int iClass, float fModifier)
{
	return g_fRocketClassTurnRate[iClass] + g_fRocketClassTurnRateIncrement[iClass] * fModifier;
}

/* CalculateDirectionToClient()
**
** As the name indicates, calculates the orientation for the rocket to move
** towards the specified client.
** -------------------------------------------------------------------------- */
void CalculateDirectionToClient(int iEntity, int iClient, float fOut[3])
{
	float fRocketPosition[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
	GetClientEyePosition(iClient, fOut);
	MakeVectorFromPoints(fRocketPosition, fOut, fOut);
	NormalizeVector(fOut, fOut);
}

/* ApplyRocketParameters()
**
** Transforms and applies the speed, direction and angles for the rocket
** entity.
** -------------------------------------------------------------------------- */
void ApplyRocketParameters(int iIndex)
{
	int iEntity = EntRefToEntIndex(g_iRocketEntity[iIndex]);
	float fAngles[3]; GetVectorAngles(g_fRocketDirection[iIndex], fAngles);
	float fVelocity[3]; CopyVectors(g_fRocketDirection[iIndex], fVelocity);
	ScaleVector(fVelocity, g_fRocketSpeed[iIndex]);
	SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fVelocity);
	SetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngles);
}

/* UpdateRocketSkin()
**
** Changes the skin of the rocket based on it's team.
** -------------------------------------------------------------------------- */
void UpdateRocketSkin(int iEntity, int iTeam, bool bNeutral)
{
	if (bNeutral == true)SetEntProp(iEntity, Prop_Send, "m_nSkin", 2);
	else SetEntProp(iEntity, Prop_Send, "m_nSkin", (iTeam == view_as<int>(TFTeam_Blue)) ? 0 : 1);
}

/* GetRandomRocketClass()
**
** Generates a random value and retrieves a rocket class based upon a chances table.
** -------------------------------------------------------------------------- */
int GetRandomRocketClass(int iSpawnerClass)
{
	int iRandom = GetURandomIntRange(0, 101);
	Handle hTable = g_hSpawnersChancesTable[iSpawnerClass];
	int iTableSize = GetArraySize(hTable);
	int iChancesLower = 0;
	int iChancesUpper = 0;
	
	for (int iEntry = 0; iEntry < iTableSize; iEntry++)
	{
		iChancesLower += iChancesUpper;
		iChancesUpper = iChancesLower + GetArrayCell(hTable, iEntry);
		
		if ((iRandom >= iChancesLower) && (iRandom < iChancesUpper))
		{
			return iEntry;
		}
	}
	
	return 0;
}

/* EmitRocketSound()
**
** Emits one of the rocket sounds
** -------------------------------------------------------------------------- */
void EmitRocketSound(RocketSound iSound, int iClass, int iEntity, int iTarget, RocketFlags iFlags)
{
	switch (iSound)
	{
		case RocketSound_Spawn:
		{
			if (TestFlags(iFlags, RocketFlag_PlaySpawnSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomSpawnSound))EmitSoundToAll(g_strRocketClassSpawnSound[iClass], iEntity);
				else EmitSoundToAll(SOUND_DEFAULT_SPAWN, iEntity);
			}
		}
		case RocketSound_Beep:
		{
			if (TestFlags(iFlags, RocketFlag_PlayBeepSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomBeepSound))EmitSoundToAll(g_strRocketClassBeepSound[iClass], iEntity);
				else EmitSoundToAll(SOUND_DEFAULT_BEEP, iEntity);
			}
		}
		case RocketSound_Alert:
		{
			if (TestFlags(iFlags, RocketFlag_PlayAlertSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomAlertSound))EmitSoundToClient(iTarget, g_strRocketClassAlertSound[iClass]);
				else EmitSoundToClient(iTarget, SOUND_DEFAULT_ALERT, _, _, _, _, 0.5);
			}
		}
	}
}

//	___			_		_	   ___ _
// | _ \___  __| |_____| |_   / __| |__ _ ______ ___ ___
// |   / _ \/ _| / / -_)  _| | (__| / _` (_-<_-</ -_|_-<
// |_|_\___/\__|_\_\___|\__|  \___|_\__,_/__/__/\___/__/
//

/* DestroyRocketClasses()
**
** Frees up all the rocket classes defined now.
** -------------------------------------------------------------------------- */
void DestroyRocketClasses()
{
	for (int iIndex = 0; iIndex < g_iRocketClassCount; iIndex++)
	{
		Handle hCmdOnSpawn = g_hRocketClassCmdsOnSpawn[iIndex];
		Handle hCmdOnKill = g_hRocketClassCmdsOnKill[iIndex];
		Handle hCmdOnExplode = g_hRocketClassCmdsOnExplode[iIndex];
		Handle hCmdOnDeflect = g_hRocketClassCmdsOnDeflect[iIndex];
		if (hCmdOnSpawn != INVALID_HANDLE)CloseHandle(hCmdOnSpawn);
		if (hCmdOnKill != INVALID_HANDLE)CloseHandle(hCmdOnKill);
		if (hCmdOnExplode != INVALID_HANDLE)CloseHandle(hCmdOnExplode);
		if (hCmdOnDeflect != INVALID_HANDLE)CloseHandle(hCmdOnDeflect);
		g_hRocketClassCmdsOnSpawn[iIndex] = INVALID_HANDLE;
		g_hRocketClassCmdsOnKill[iIndex] = INVALID_HANDLE;
		g_hRocketClassCmdsOnExplode[iIndex] = INVALID_HANDLE;
		g_hRocketClassCmdsOnDeflect[iIndex] = INVALID_HANDLE;
	}
	g_iRocketClassCount = 0;
	ClearTrie(g_hRocketClassTrie);
}

//	___							 ___	 _	   _					 _	  ___ _
// / __|_ __  __ ___ __ ___ _   | _ \___(_)_ _| |_ ___  __ _ _ _  __| |  / __| |__ _ ______ ___ ___
// \__ \ '_ \/ _` \ V  V / ' \  |  _/ _ \ | ' \  _(_-< / _` | ' \/ _` | | (__| / _` (_-<_-</ -_|_-<
// |___/ .__/\__,_|\_/\_/|_||_| |_| \___/_|_||_\__/__/ \__,_|_||_\__,_|  \___|_\__,_/__/__/\___/__/
//		|_|

/* DestroySpawners()
**
** Frees up all the spawner points defined up to now.
** -------------------------------------------------------------------------- */
void DestroySpawners()
{
	for (int iIndex = 0; iIndex < g_iSpawnersCount; iIndex++)
	{
		CloseHandle(g_hSpawnersChancesTable[iIndex]);
	}
	g_iSpawnersCount = 0;
	g_iSpawnPointsRedCount = 0;
	g_iSpawnPointsBluCount = 0;
	g_defaultRedSpawner = -1;
	g_defaultBluSpawner = -1;
	g_strSavedClassName[0] = '\0';
	ClearTrie(g_hSpawnersTrie);
}

/* PopulateSpawnPoints()
**
** Iterates through all the possible spawn points and assigns them an spawner.
** -------------------------------------------------------------------------- */
void PopulateSpawnPoints()
{
	// Clear the current settings
	g_iSpawnPointsRedCount = 0;
	g_iSpawnPointsBluCount = 0;
	
	// Iterate through all the info target points and check 'em out.
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "info_target")) != -1)
	{
		char strName[32]; GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
		if ((StrContains(strName, "rocket_spawn_red") != -1) || (StrContains(strName, "tf_dodgeball_red") != -1))
		{
			// Find most appropiate spawner class for this entity.
			int iIndex = FindSpawnerByName(strName);
			if (!IsValidRocket(iIndex))iIndex = g_defaultRedSpawner;
			
			// Upload to point list
			g_iSpawnPointsRedClass[g_iSpawnPointsRedCount] = iIndex;
			g_iSpawnPointsRedEntity[g_iSpawnPointsRedCount] = iEntity;
			g_iSpawnPointsRedCount++;
		}
		if ((StrContains(strName, "rocket_spawn_blue") != -1) || (StrContains(strName, "tf_dodgeball_blu") != -1))
		{
			// Find most appropiate spawner class for this entity.
			int iIndex = FindSpawnerByName(strName);
			if (!IsValidRocket(iIndex))iIndex = g_defaultBluSpawner;
			
			// Upload to point list
			g_iSpawnPointsBluClass[g_iSpawnPointsBluCount] = iIndex;
			g_iSpawnPointsBluEntity[g_iSpawnPointsBluCount] = iEntity;
			g_iSpawnPointsBluCount++;
		}
	}
	
	// Check if there exists spawn points
	if (g_iSpawnPointsRedCount == 0)
		SetFailState("No RED spawn points found on this map.");
	
	if (g_iSpawnPointsBluCount == 0)
		SetFailState("No BLU spawn points found on this map.");
	
	
	//ObserverPoint
	float opPos[3];
	float opAng[3];
	
	int spawner = GetRandomInt(0, 1);
	if (spawner == 0)
		spawner = g_iSpawnPointsRedEntity[0];
	else
		spawner = g_iSpawnPointsBluEntity[0];
	
	if (IsValidEntity(spawner) && spawner > MAXPLAYERS)
	{
		GetEntPropVector(spawner, Prop_Data, "m_vecOrigin", opPos);
		GetEntPropVector(spawner, Prop_Data, "m_angAbsRotation", opAng);
		g_observer = CreateEntityByName("info_observer_point");
		DispatchKeyValue(g_observer, "Angles", "90 0 0");
		DispatchKeyValue(g_observer, "TeamNum", "0");
		DispatchKeyValue(g_observer, "StartDisabled", "0");
		DispatchSpawn(g_observer);
		AcceptEntityInput(g_observer, "Enable");
		TeleportEntity(g_observer, opPos, opAng, NULL_VECTOR);
	}
	else
	{
		g_observer = -1;
	}
	
}

/* FindSpawnerByName()
**
** Finds the first spawner wich contains the given name.
** -------------------------------------------------------------------------- */
int FindSpawnerByName(char strName[32])
{
	int iIndex = -1;
	GetTrieValue(g_hSpawnersTrie, strName, iIndex);
	return iIndex;
}


/*
**����������������������������������������������������������������������������������
**	  ______										  __
**   / ____/___  ____ ___  ____ ___  ____ _____  ____/ /____
**  / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / ___/
** / /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ (__  )
** \____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/____/
**
**����������������������������������������������������������������������������������
*/






/* ExecuteCommands()
**
** The core of the plugin's event system, unpacks and correctly formats the
** given command strings to be executed.
** -------------------------------------------------------------------------- */
void ExecuteCommands(Handle hDataPack, int iClass, int iRocket, int iOwner, int iTarget, int iLastDead, float fSpeed, int iNumDeflections)
{
	ResetPack(hDataPack, false);
	int iNumCommands = ReadPackCell(hDataPack);
	while (iNumCommands-- > 0)
	{
		char strCmd[256];
		char strBuffer[8];
		ReadPackString(hDataPack, strCmd, sizeof(strCmd));
		ReplaceString(strCmd, sizeof(strCmd), "@name", g_strRocketClassLongName[iClass]);
		Format(strBuffer, sizeof(strBuffer), "%i", iRocket); ReplaceString(strCmd, sizeof(strCmd), "@rocket", strBuffer);
		Format(strBuffer, sizeof(strBuffer), "%i", iOwner); ReplaceString(strCmd, sizeof(strCmd), "@owner", strBuffer);
		Format(strBuffer, sizeof(strBuffer), "%i", iTarget); ReplaceString(strCmd, sizeof(strCmd), "@target", strBuffer);
		Format(strBuffer, sizeof(strBuffer), "%i", iLastDead); ReplaceString(strCmd, sizeof(strCmd), "@dead", strBuffer);
		Format(strBuffer, sizeof(strBuffer), "%f", fSpeed); ReplaceString(strCmd, sizeof(strCmd), "@speed", strBuffer);
		Format(strBuffer, sizeof(strBuffer), "%i", iNumDeflections); ReplaceString(strCmd, sizeof(strCmd), "@deflections", strBuffer);
		ServerCommand(strCmd);
	}
}

/*
**����������������������������������������������������������������������������������
**	  ______			_____
**   / ____/___  ____  / __(_)___ _
**  / /   / __ \/ __ \/ /_/ / __ `/
** / /___/ /_/ / / / / __/ / /_/ /
** \____/\____/_/ /_/_/ /_/\__, /
**						  /____/
**����������������������������������������������������������������������������������
*/

/* ParseConfiguration()
**
** Parses a Dodgeball configuration file. It doesn't clear any of the previous
** data, so multiple files can be parsed.
** -------------------------------------------------------------------------- */
bool ParseConfigurations(char strConfigFile[] = "general.cfg")
{
	// Parse configuration
	char strPath[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	Format(strFileName, sizeof(strFileName), "configs/dodgeball/%s", strConfigFile);
	BuildPath(Path_SM, strPath, sizeof(strPath), strFileName);
	
	// Try to parse if it exists
	LogMessage("Executing configuration file %s", strPath);
	if (FileExists(strPath, true))
	{
		KeyValues kvConfig = CreateKeyValues("TF2_Dodgeball");
		
		if (FileToKeyValues(kvConfig, strPath) == false)
			SetFailState("Error while parsing the configuration file.");
		
		kvConfig.GotoFirstSubKey();
		
		// Parse the subsections
		do
		{
			char strSection[64];
			KvGetSectionName(kvConfig, strSection, sizeof(strSection));
			
			
			if (StrEqual(strSection, "classes"))
				ParseClasses(kvConfig);
			else if (StrEqual(strSection, "spawners"))
				ParseSpawners(kvConfig);
		}
		while (KvGotoNextKey(kvConfig));
		
		CloseHandle(kvConfig);
	}
}


/* ParseClasses()
**
** Parses the rocket classes data from the given configuration file.
** -------------------------------------------------------------------------- */
void ParseClasses(Handle kvConfig)
{
	char strName[64];
	char strBuffer[256];
	
	KvGotoFirstSubKey(kvConfig);
	do
	{
		int iIndex = g_iRocketClassCount;
		RocketFlags iFlags;
		
		// Basic parameters
		KvGetSectionName(kvConfig, strName, sizeof(strName)); strcopy(g_strRocketClassName[iIndex], 16, strName);
		KvGetString(kvConfig, "name", strBuffer, sizeof(strBuffer)); strcopy(g_strRocketClassLongName[iIndex], 32, strBuffer);
		if (KvGetString(kvConfig, "model", strBuffer, sizeof(strBuffer)))
		{
			strcopy(g_strRocketClassModel[iIndex], PLATFORM_MAX_PATH, strBuffer);
			if (strlen(g_strRocketClassModel[iIndex]) != 0)
			{
				iFlags |= RocketFlag_CustomModel;
				if (KvGetNum(kvConfig, "is animated", 0))iFlags |= RocketFlag_IsAnimated;
			}
		}
		
		KvGetString(kvConfig, "behaviour", strBuffer, sizeof(strBuffer), "homing");
		if (StrEqual(strBuffer, "homing"))g_iRocketClassBehaviour[iIndex] = Behaviour_Homing;
		else g_iRocketClassBehaviour[iIndex] = Behaviour_Unknown;
		
		if (KvGetNum(kvConfig, "play spawn sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlaySpawnSound;
			if (KvGetString(kvConfig, "spawn sound", g_strRocketClassSpawnSound[iIndex], PLATFORM_MAX_PATH) && (strlen(g_strRocketClassSpawnSound[iIndex]) != 0))
			{
				iFlags |= RocketFlag_CustomSpawnSound;
			}
		}
		
		if (KvGetNum(kvConfig, "play beep sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlayBeepSound;
			g_fRocketClassBeepInterval[iIndex] = KvGetFloat(kvConfig, "beep interval", 0.5);
			if (KvGetString(kvConfig, "beep sound", g_strRocketClassBeepSound[iIndex], PLATFORM_MAX_PATH) && (strlen(g_strRocketClassBeepSound[iIndex]) != 0))
			{
				iFlags |= RocketFlag_CustomBeepSound;
			}
		}
		
		if (KvGetNum(kvConfig, "play alert sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlayAlertSound;
			if (KvGetString(kvConfig, "alert sound", g_strRocketClassAlertSound[iIndex], PLATFORM_MAX_PATH) && strlen(g_strRocketClassAlertSound[iIndex]) != 0)
			{
				iFlags |= RocketFlag_CustomAlertSound;
			}
		}
		
		// Behaviour modifiers
		if (KvGetNum(kvConfig, "elevate on deflect", 1) == 1)iFlags |= RocketFlag_ElevateOnDeflect;
		if (KvGetNum(kvConfig, "neutral rocket", 0) == 1)iFlags |= RocketFlag_IsNeutral;
		
		// Movement parameters
		g_fRocketClassDamage[iIndex] = KvGetFloat(kvConfig, "damage");
		g_fRocketClassDamageIncrement[iIndex] = KvGetFloat(kvConfig, "damage increment");
		g_fRocketClassCritChance[iIndex] = KvGetFloat(kvConfig, "critical chance");
		g_fRocketClassSpeed[iIndex] = KvGetFloat(kvConfig, "speed");
		g_fSavedSpeed = g_fRocketClassSpeed[iIndex];
		g_fRocketClassSpeedIncrement[iIndex] = KvGetFloat(kvConfig, "speed increment");
		g_fSavedSpeedIncrement = g_fRocketClassSpeedIncrement[iIndex];
		g_fRocketClassTurnRate[iIndex] = KvGetFloat(kvConfig, "turn rate");
		g_fRocketClassTurnRateIncrement[iIndex] = KvGetFloat(kvConfig, "turn rate increment");
		g_fRocketClassElevationRate[iIndex] = KvGetFloat(kvConfig, "elevation rate");
		g_fRocketClassElevationLimit[iIndex] = KvGetFloat(kvConfig, "elevation limit");
		g_fRocketClassControlDelay[iIndex] = KvGetFloat(kvConfig, "control delay");
		g_fRocketClassPlayerModifier[iIndex] = KvGetFloat(kvConfig, "no. players modifier");
		g_fRocketClassRocketsModifier[iIndex] = KvGetFloat(kvConfig, "no. rockets modifier");
		g_fRocketClassTargetWeight[iIndex] = KvGetFloat(kvConfig, "direction to target weight");
		
		// Events
		Handle hCmds = INVALID_HANDLE;
		KvGetString(kvConfig, "on spawn", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnSpawnCmd; g_hRocketClassCmdsOnSpawn[iIndex] = hCmds; }
		KvGetString(kvConfig, "on deflect", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnDeflectCmd; g_hRocketClassCmdsOnDeflect[iIndex] = hCmds; }
		KvGetString(kvConfig, "on kill", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnKillCmd; g_hRocketClassCmdsOnKill[iIndex] = hCmds; }
		KvGetString(kvConfig, "on explode", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnExplodeCmd; g_hRocketClassCmdsOnExplode[iIndex] = hCmds; }
		
		// Done
		SetTrieValue(g_hRocketClassTrie, strName, iIndex);
		g_iRocketClassFlags[iIndex] = iFlags;
		g_iRocketClassCount++;
	}
	while (KvGotoNextKey(kvConfig));
	KvGoBack(kvConfig);
}

/* ParseSpawners()
**
** Parses the spawn points classes data from the given configuration file.
** -------------------------------------------------------------------------- */
void ParseSpawners(KeyValues kvConfig)
{
	kvConfig.JumpToKey("spawners"); //jump to spawners section
	char strBuffer[256];
	kvConfig.GotoFirstSubKey(); //goto to first subkey of "spawners" section
	
	do
	{
		int iIndex = g_iSpawnersCount;
		
		// Basic parameters
		kvConfig.GetSectionName(strBuffer, sizeof(strBuffer)); //okay, here we got section name, as example, red
		strcopy(g_strSpawnersName[iIndex], 32, strBuffer); //here we copied it to the g_strSpawnersName array
		g_iSpawnersMaxRockets[iIndex] = kvConfig.GetNum("max rockets", 1); //get some values...
		g_fSpawnersInterval[iIndex] = kvConfig.GetFloat("interval", 1.0);
		
		// Chances table
		g_hSpawnersChancesTable[iIndex] = CreateArray(); //not interested in this
		for (int iClassIndex = 0; iClassIndex < g_iRocketClassCount; iClassIndex++)
		{
			Format(strBuffer, sizeof(strBuffer), "%s%%", g_strRocketClassName[iClassIndex]);
			PushArrayCell(g_hSpawnersChancesTable[iIndex], KvGetNum(kvConfig, strBuffer, 0));
			if (KvGetNum(kvConfig, strBuffer, 0) == 100)strcopy(g_strSavedClassName, sizeof(g_strSavedClassName), g_strRocketClassLongName[iClassIndex]);
		}
		
		// Done.
		SetTrieValue(g_hSpawnersTrie, g_strSpawnersName[iIndex], iIndex); //okay, push section name to g_hSpawnersTrie
		g_iSpawnersCount++;
	} while (kvConfig.GotoNextKey());
	
	kvConfig.Rewind(); //rewind
	
	GetTrieValue(g_hSpawnersTrie, "Red", g_defaultRedSpawner); //get value by section name, section name exists in the g_hSpawnersTrie, everything should work
	GetTrieValue(g_hSpawnersTrie, "Blue", g_defaultBluSpawner);
}

/* ParseCommands()
**
** Part of the event system, parses the given command strings and packs them
** to a Datapack.
** -------------------------------------------------------------------------- */
Handle ParseCommands(char[] strLine)
{
	TrimString(strLine);
	if (strlen(strLine) == 0)
	{
		return INVALID_HANDLE;
	}
	else
	{
		char strStrings[8][255];
		int iNumStrings = ExplodeString(strLine, ";", strStrings, 8, 255);
		
		Handle hDataPack = CreateDataPack();
		WritePackCell(hDataPack, iNumStrings);
		for (int i = 0; i < iNumStrings; i++)
		{
			WritePackString(hDataPack, strStrings[i]);
		}
		
		return hDataPack;
	}
}

/*
**����������������������������������������������������������������������������������
**	 ______			   __
**  /_  __/___  ____  / /____
**   / / / __ \/ __ \/ / ___/
**  / / / /_/ / /_/ / (__  )
** /_/  \____/\____/_/____/
**
**����������������������������������������������������������������������������������
*/

/* ApplyDamage()
**
** Applies a damage to a player.
** -------------------------------------------------------------------------- */
public Action ApplyDamage(Handle hTimer, any hDataPack)
{
	ResetPack(hDataPack, false);
	int iClient = ReadPackCell(hDataPack);
	int iDamage = ReadPackCell(hDataPack);
	CloseHandle(hDataPack);
	SlapPlayer(iClient, iDamage, true);
}

/* CopyVectors()
**
** Copies the contents from a vector to another.
** -------------------------------------------------------------------------- */
stock void CopyVectors(float fFrom[3], float fTo[3])
{
	fTo[0] = fFrom[0];
	fTo[1] = fFrom[1];
	fTo[2] = fFrom[2];
}

/* LerpVectors()
**
** Calculates the linear interpolation of the two given vectors and stores
** it on the third one.
** -------------------------------------------------------------------------- */
stock void LerpVectors(float fA[3], float fB[3], float fC[3], float t)
{
	if (t < 0.0)t = 0.0;
	if (t > 1.0)t = 1.0;
	
	fC[0] = fA[0] + (fB[0] - fA[0]) * t;
	fC[1] = fA[1] + (fB[1] - fA[1]) * t;
	fC[2] = fA[2] + (fB[2] - fA[2]) * t;
}

/* IsValidClient()
**
** Checks if the given client index is valid, and if it's alive or not.
** -------------------------------------------------------------------------- */
stock bool IsValidClient(int iClient, bool bAlive = false)
{
	if (iClient >= 1 && 
		iClient <= MaxClients && 
		IsClientConnected(iClient) && 
		IsClientInGame(iClient) && 
		(bAlive == false || IsPlayerAlive(iClient)))
	{
		return true;
	}
	
	return false;
}

/* BothTeamsPlaying()
**
** Checks if there are players on both teams.
** -------------------------------------------------------------------------- */
stock bool BothTeamsPlaying()
{
	bool bRedFound;
	bool bBluFound;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient, true) == false)continue;
		int iTeam = GetClientTeam(iClient);
		if (iTeam == view_as<int>(TFTeam_Red))bRedFound = true;
		if (iTeam == view_as<int>(TFTeam_Blue))bBluFound = true;
	}
	return bRedFound && bBluFound;
}

/* CountAlivePlayers()
**
** Retrieves the number of players alive.
** -------------------------------------------------------------------------- */
stock int CountAlivePlayers()
{
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient, true))iCount++;
	}
	return iCount;
}

/* SelectTarget()
**
** Determines a random target of the given team for the homing rocket.
** -------------------------------------------------------------------------- */
stock int SelectTarget(int iTeam, int iRocket = -1)
{
	int iTarget = -1;
	float fTargetWeight = 0.0;
	float fRocketPosition[3];
	float fRocketDirection[3];
	float fWeight;
	bool bUseRocket;
	
	if (iRocket != -1)
	{
		int iClass = g_iRocketClass[iRocket];
		int iEntity = EntRefToEntIndex(g_iRocketEntity[iRocket]);
		
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
		CopyVectors(g_fRocketDirection[iRocket], fRocketDirection);
		fWeight = g_fRocketClassTargetWeight[iClass];
		
		bUseRocket = true;
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		// If the client isn't connected, skip.
		if (!IsValidClient(iClient, true))continue;
		if (iTeam && GetClientTeam(iClient) != iTeam)continue;
		
		// Determine if this client should be the target.
		float fNewWeight = GetURandomFloatRange(0.0, 100.0);
		
		if (bUseRocket == true)
		{
			float fClientPosition[3]; GetClientEyePosition(iClient, fClientPosition);
			float fDirectionToClient[3]; MakeVectorFromPoints(fRocketPosition, fClientPosition, fDirectionToClient);
			fNewWeight += GetVectorDotProduct(fRocketDirection, fDirectionToClient) * fWeight;
		}
		
		if ((iTarget == -1) || fNewWeight >= fTargetWeight)
		{
			iTarget = iClient;
			fTargetWeight = fNewWeight;
		}
	}
	
	return iTarget;
}

/* StopSoundToAll()
**
** Stops a sound for all the clients on the given channel.
** -------------------------------------------------------------------------- */
stock void StopSoundToAll(int iChannel, const char[] strSound)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClient(iClient))StopSound(iClient, iChannel, strSound);
	}
}

/* PlayParticle()
**
** Plays a particle system at the given location & angles.
** -------------------------------------------------------------------------- */
stock void PlayParticle(float fPosition[3], float fAngles[3], char[] strParticleName, float fEffectTime = 5.0, float fLifeTime = 9.0)
{
	int iEntity = CreateEntityByName("info_particle_system");
	if (iEntity && IsValidEdict(iEntity))
	{
		TeleportEntity(iEntity, fPosition, fAngles, NULL_VECTOR);
		DispatchKeyValue(iEntity, "effect_name", strParticleName);
		ActivateEntity(iEntity);
		AcceptEntityInput(iEntity, "Start");
		CreateTimer(fEffectTime, StopParticle, EntIndexToEntRef(iEntity));
		CreateTimer(fLifeTime, KillParticle, EntIndexToEntRef(iEntity));
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
	}
}

/* StopParticle()
**
** Turns of the particle system. Automatically called by PlayParticle
** -------------------------------------------------------------------------- */
public Action StopParticle(Handle hTimer, any iEntityRef)
{
	if (iEntityRef != INVALID_ENT_REFERENCE)
	{
		int iEntity = EntRefToEntIndex(iEntityRef);
		if (iEntity && IsValidEntity(iEntity))
		{
			AcceptEntityInput(iEntity, "Stop");
		}
	}
}

/* KillParticle()
**
** Destroys the particle system. Automatically called by PlayParticle
** -------------------------------------------------------------------------- */
public Action KillParticle(Handle hTimer, any iEntityRef)
{
	if (iEntityRef != INVALID_ENT_REFERENCE)
	{
		int iEntity = EntRefToEntIndex(iEntityRef);
		if (iEntity && IsValidEntity(iEntity))
		{
			RemoveEdict(iEntity);
		}
	}
}

/* PrecacheParticle()
**
** Forces the client to precache a particle system.
** -------------------------------------------------------------------------- */
stock void PrecacheParticle(char[] strParticleName)
{
	PlayParticle(view_as<float>( { 0.0, 0.0, 0.0 } ), view_as<float>( { 0.0, 0.0, 0.0 } ), strParticleName, 0.1, 0.1);
}

/* FindEntityByClassnameSafe()
**
** Used to iterate through entity types, avoiding problems in cases where
** the entity may not exist anymore.
** -------------------------------------------------------------------------- */
stock void FindEntityByClassnameSafe(int iStart, const char[] strClassname)
{
	while (iStart > -1 && !IsValidEntity(iStart))
	{
		iStart--;
	}
	return FindEntityByClassname(iStart, strClassname);
}

/* GetAnalogueTeam()
**
** Gets the analogue team for this. In case of Red, it's Blue, and viceversa.
** -------------------------------------------------------------------------- */
stock int GetAnalogueTeam(int iTeam)
{
	if (iTeam == view_as<int>(TFTeam_Red))return view_as<int>(TFTeam_Blue);
	return view_as<int>(TFTeam_Red);
}

/* ShowHiddenMOTDPanel()
**
** Shows a hidden MOTD panel, useful for streaming music.
** -------------------------------------------------------------------------- */
stock void ShowHiddenMOTDPanel(int iClient, char[] strTitle, char[] strMsg, char[] strType = "2")
{
	Handle hPanel = CreateKeyValues("data");
	KvSetString(hPanel, "title", strTitle);
	KvSetString(hPanel, "type", strType);
	KvSetString(hPanel, "msg", strMsg);
	ShowVGUIPanel(iClient, "info", hPanel, false);
	CloseHandle(hPanel);
}

/* PrecacheSoundEx()
**
** Precaches a sound and adds it to the download table.
** -------------------------------------------------------------------------- */
stock void PrecacheSoundEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false)
{
	char strFinalPath[PLATFORM_MAX_PATH];
	Format(strFinalPath, sizeof(strFinalPath), "sound/%s", strFileName);
	PrecacheSound(strFileName, bPreload);
	if (bAddToDownloadTable == true)AddFileToDownloadsTable(strFinalPath);
}

/* PrecacheModelEx()
**
** Precaches a models and adds it to the download table.
** -------------------------------------------------------------------------- */
stock void PrecacheModelEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false)
{
	PrecacheModel(strFileName, bPreload);
	if (bAddToDownloadTable)
	{
		char strDepFileName[PLATFORM_MAX_PATH];
		Format(strDepFileName, sizeof(strDepFileName), "%s.res", strFileName);
		
		if (FileExists(strDepFileName))
		{
			// Open stream, if possible
			Handle hStream = OpenFile(strDepFileName, "r");
			if (hStream == INVALID_HANDLE) { LogMessage("Error, can't read file containing model dependencies."); return; }
			
			while (!IsEndOfFile(hStream))
			{
				char strBuffer[PLATFORM_MAX_PATH];
				ReadFileLine(hStream, strBuffer, sizeof(strBuffer));
				CleanString(strBuffer);
				
				// If file exists...
				if (FileExists(strBuffer, true))
				{
					// Precache depending on type, and add to download table
					if (StrContains(strBuffer, ".vmt", false) != -1)PrecacheDecal(strBuffer, true);
					else if (StrContains(strBuffer, ".mdl", false) != -1)PrecacheModel(strBuffer, true);
					else if (StrContains(strBuffer, ".pcf", false) != -1)PrecacheGeneric(strBuffer, true);
					AddFileToDownloadsTable(strBuffer);
				}
			}
			
			// Close file
			CloseHandle(hStream);
		}
	}
}

/* CleanString()
**
** Cleans the given string from any illegal character.
** -------------------------------------------------------------------------- */
stock void CleanString(char[] strBuffer)
{
	// Cleanup any illegal characters
	int Length = strlen(strBuffer);
	for (int iPos = 0; iPos < Length; iPos++)
	{
		switch (strBuffer[iPos])
		{
			case '\r':strBuffer[iPos] = ' ';
			case '\n':strBuffer[iPos] = ' ';
			case '\t':strBuffer[iPos] = ' ';
		}
	}
	
	// Trim string
	TrimString(strBuffer);
}

/* FMax()
**
** Returns the maximum of the two values given.
** -------------------------------------------------------------------------- */
stock float FMax(float a, float b)
{
	return (a > b) ? a:b;
}

/* FMin()
**
** Returns the minimum of the two values given.
** -------------------------------------------------------------------------- */
stock float FMin(float a, float b)
{
	return (a < b) ? a:b;
}

/* GetURandomIntRange()
**
**
** -------------------------------------------------------------------------- */
stock int GetURandomIntRange(const int iMin, const int iMax)
{
	return iMin + (GetURandomInt() % (iMax - iMin + 1));
}

/* GetURandomFloatRange()
**
**
** -------------------------------------------------------------------------- */
stock float GetURandomFloatRange(float fMin, float fMax)
{
	return fMin + (GetURandomFloat() * (fMax - fMin));
}

// Pyro vision
public void tf2dodgeball_hooks(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarBool(CVAR_AutoPyroVision))
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				TF2Attrib_SetByName(i, PYROVISION_ATTRIBUTE, 1.0);
			}
		}
	}
	else
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				TF2Attrib_RemoveByName(i, PYROVISION_ATTRIBUTE);
			}
		}
	}
	
	if (convar == CVAR_MaxRocketBounces)
		g_config_iMaxBounces = StringToInt(newValue);
}

// Asherkins RocketBounce

public void OnEntityCreated(int entity, const char[] classname) {
	if (g_mapIsTFDB && StrEqual(classname, "tf_projectile_rocket", true)) {
		if (StrEqual(classname, "tf_projectile_rocket") || StrEqual(classname, "tf_projectile_sentryrocket")) {
			if (IsValidEntity(entity)) {
				SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", entity);
				SetEntPropEnt(entity, Prop_Send, "m_hLauncher", entity);
			}
		}
		g_nBounces[entity] = 0;
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
	}
}

public Action OnStartTouch(int entity, int other) {
	if (other > 0 && other <= MaxClients)
		return Plugin_Continue;
	
	// Only allow a rocket to bounce x times.
	if (g_nBounces[entity] >= g_config_iMaxBounces)
		return Plugin_Continue;
	
	SDKHook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public Action OnTouch(int entity, int other)
{
	float vOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	
	float vAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
	
	float vVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);
	
	if (!TR_DidHit(trace)) {
		CloseHandle(trace);
		return Plugin_Continue;
	}
	
	float vNormal[3];
	TR_GetPlaneNormal(trace, vNormal);
	
	//PrintToServer("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);
	
	CloseHandle(trace);
	
	float dotProduct = GetVectorDotProduct(vNormal, vVelocity);
	
	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);
	
	float vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);
	
	float vNewAngles[3];
	GetVectorAngles(vBounceVec, vNewAngles);
	
	//PrintToChatAll("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
	//PrintToChatAll("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
	
	TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);
	
	g_nBounces[entity]++;
	
	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public bool TEF_ExcludeEntity(int entity, int contentsMask, any data)
{
	return (entity != data);
}

void preventAirblast(int clientId, bool prevent)
{
	int flags;
	
	if (prevent == true) {
		PVAR_AIRBLAST_PREVENTION[clientId] = true;
		flags = GetEntityFlags(clientId) | FL_NOTARGET;
	} else {
		PVAR_AIRBLAST_PREVENTION[clientId] = false;
		flags = GetEntityFlags(clientId) & ~FL_NOTARGET;
	}
	
	SetEntityFlags(clientId, flags);
}

public Action TauntCheck(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!g_mapIsTFDB)
		return Plugin_Continue;
	
	switch (damagecustom)
	{
		case TF_CUSTOM_TAUNT_ARMAGEDDON:
		{
			damage = 0.0;
			return Plugin_Changed;
		}
		
	}
	return Plugin_Continue;
}

void checkStolenRocket(int clientId, int entId)
{
	if (EntRefToEntIndex(g_iRocketTarget[entId]) != clientId && !bStealArray[clientId][stoleRocket])
	{
		bStealArray[clientId][stoleRocket] = true;
		if (bStealArray[clientId][rocketsStolen] < GetConVarInt(CVAR_StealPreventionCount))
		{
			bStealArray[clientId][rocketsStolen]++;
			CreateTimer(0.1, tStealTimer, GetClientUserId(clientId), TIMER_FLAG_NO_MAPCHANGE);
			SlapPlayer(clientId, 0, true);
			CPrintToChat(clientId, "{mediumpurple}ᴅʙ {black}» {default}Do not steal rockets. [Warning {dodgerblue}%i{default}/{dodgerblue}%i{default}]", bStealArray[clientId][rocketsStolen], GetConVarInt(CVAR_StealPreventionCount));
		}
		else
		{
			ForcePlayerSuicide(clientId);
			//DeleteRocket(entId);
			CPrintToChat(clientId, "{mediumpurple}ᴅʙ {black}» {default}You have been slain for stealing rockets.");
			CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {dodgerblue}%N {default}was slain for stealing rockets.", clientId);
		}
	}
}

void checkRoundDelays(int entId)
{
	int iEntity = EntRefToEntIndex(g_iRocketEntity[entId]);
	int iTarget = EntRefToEntIndex(g_iRocketTarget[entId]);
	float timeToCheck;
	if (g_iRocketDeflections[entId] == 0)
		timeToCheck = g_lastSpawnTime;
	else
		timeToCheck = g_fRocketLastDeflectionTime[entId];
	
	if (iTarget != INVALID_ENT_REFERENCE && (GetGameTime() - timeToCheck) >= GetConVarFloat(CVAR_DelayPreventionTime))
	{
		g_fRocketSpeed[entId] += GetConVarFloat(CVAR_DelayPreventionSpeedup);
		if (!g_bPreventingDelay)
		{
			CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {dodgerblue}%N {default}is delaying, the rocket will now speed up.", iTarget);
			EmitSoundToAll(SOUND_DEFAULT_SPEEDUPALERT, iEntity, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
		}
		g_bPreventingDelay = true;
	}
}

/* SetMainRocketClass()
**
** Takes a specified rocket class index and sets it as the only rocket class able to spawn.
** -------------------------------------------------------------------------- */
void SetMainRocketClass(int Index, int client = 0)
{
	int iSpawnerClassRed = g_iSpawnPointsRedClass[g_iCurrentRedSpawn];
	char strBufferRed[256];
	strcopy(strBufferRed, sizeof(strBufferRed), "Red");
	
	Format(strBufferRed, sizeof(strBufferRed), "%s%%", g_strRocketClassName[Index]);
	SetArrayCell(g_hSpawnersChancesTable[iSpawnerClassRed], Index, 100);
	
	for (int iClassIndex = 0; iClassIndex < g_iRocketClassCount; iClassIndex++)
	{
		if (!(iClassIndex == Index))
		{
			Format(strBufferRed, sizeof(strBufferRed), "%s%%", g_strRocketClassName[iClassIndex]);
			SetArrayCell(g_hSpawnersChancesTable[iSpawnerClassRed], iClassIndex, 0);
		}
	}
	
	int iSpawnerClassBlu = g_iSpawnPointsBluClass[g_iCurrentBluSpawn];
	char strBufferBlue[256];
	strcopy(strBufferBlue, sizeof(strBufferBlue), "Blue");
	
	Format(strBufferBlue, sizeof(strBufferBlue), "%s%%", g_strRocketClassName[Index]);
	SetArrayCell(g_hSpawnersChancesTable[iSpawnerClassBlu], Index, 100);
	
	char strSelectionBlue[256];
	strcopy(strSelectionBlue, sizeof(strBufferBlue), strBufferBlue);
	
	for (int iClassIndex = 0; iClassIndex < g_iRocketClassCount; iClassIndex++)
	{
		if (!(iClassIndex == Index))
		{
			Format(strBufferBlue, sizeof(strBufferBlue), "%s%%", g_strRocketClassName[iClassIndex]);
			SetArrayCell(g_hSpawnersChancesTable[iSpawnerClassBlu], iClassIndex, 0);
		}
	}
	
	int iClass = GetRandomRocketClass(iSpawnerClassRed);
	strcopy(g_strSavedClassName, sizeof(g_strSavedClassName), g_strRocketClassLongName[iClass]);
	
	CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {deodgerblue}%N{default} changed the rocket class to {dodgerblue}%s{default}.", client, g_strRocketClassLongName[iClass]);
}

float CalculateSpeed(float speed)
{
	return speed * (15.0 / 350.0);
}

public Action tStealTimer(Handle hTimer, int iClientUid)
{
	int iClient = GetClientOfUserId(iClientUid);
	bStealArray[iClient][stoleRocket] = false;
}

/*void AttachParticle(int iEntity, char[] strParticleType)
{
	int iParticle = CreateEntityByName("info_particle_system");

	char strName[128];
	if (IsValidEdict(iParticle))
	{
		float fPos[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPos);
		fPos[2] += 10;
		TeleportEntity(iParticle, fPos, NULL_VECTOR, NULL_VECTOR);

		Format(strName, sizeof(strName), "target%i", iEntity);
		DispatchKeyValue(iEntity, "targetname", strName);

		DispatchKeyValue(iParticle, "targetname", "tf2particle");
		DispatchKeyValue(iParticle, "parentname", strName);
		DispatchKeyValue(iParticle, "effect_name", strParticleType);
		DispatchSpawn(iParticle);
		SetVariantString(strName);
		AcceptEntityInput(iParticle, "SetParent", iParticle, iParticle, 0);
		SetVariantString("");
		AcceptEntityInput(iParticle, "SetParentAttachment", iParticle, iParticle, 0);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "start");

		g_RocketParticle[iEntity] = iParticle;
	}
}*/

stock void CreateTempParticle(char[] particle, int entity = -1, float origin[3] = NULL_VECTOR, float angles[3] =  { 0.0, 0.0, 0.0 }, bool resetparticles = false)
{
	int tblidx = FindStringTable("ParticleEffectNames");
	
	char tmp[256];
	int stridx = INVALID_STRING_INDEX;
	
	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, particle, false))
		{
			stridx = i;
			break;
		}
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iAttachType", 1);
	TE_WriteNum("m_bResetParticles", resetparticles);
	TE_SendToAll();
}

stock void ClearTempParticles(int client)
{
	float empty[3];
	CreateTempParticle("sandwich_fx", client, empty, empty, true);
}

/*void StolenRocket(int iClient, int iTarget)
{
	if (iTarget != iClient && GetClientTeam(iClient) == GetClientTeam(iTarget))
	{
		PrintToChatAll("\x03%N\x01 stole \x03%N\x01's rocket!", iClient, iTarget);
		g_stolen[iClient]++;
		if (g_stolen[iClient] >= GetConVarInt(CVAR_StealPreventionCount))
		{
			g_stolen[iClient] = 0;
			ForcePlayerSuicide(iClient);
			PrintToChat(iClient, "\x03You stole %d rockets and was slayed.", CVAR_StealPreventionCount);
		}
	}
}*/


// EOF

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
 * WHAT TO DO NEXT: -> EXTEND THE 'PD. NUMBER #TEXT' ORDER [80%] and 
 * 1vs1 AUTO GODMODE [100%] , CLEANUP CODE [70%], [0%] OWN CHATMESSAGES, EXTENDED TFDB MENU (SPAWN ROCKET) [20%], 
 * OWN NANOBOT - replacing with Advanced Bot by soul, JUGGERNAUT (MAYBE INSIDE DODGEBALL PLUGIN) [0%], SESSION TOP SPEED [98%] (LEARN HOW TO CREATE STATS[CONFIGS TO SAVE])
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
// PD.2 #DEFINES
//
/* PD.2:1 #PLUGIN DEFINES */
#pragma newdecls required
#pragma semicolon 1	
#define PLUGIN_NAME 					"Yet Another Dodgeball"
#define PLUGIN_AUTHOR 					"Damizean (rewritten by saka)"
#define PLUGIN_VERSION					"1.5.3"
#define PLUGIN_CONTACT					"https://l03.dev/"
#define FPS_LOGIC_RATE					20.0
#define FPS_LOGIC_INTERVAL				1.0 / FPS_LOGIC_RATE
#define	MAX_EDICT_BITS					11
#define	MAX_EDICTS						(1 << MAX_EDICT_BITS)
#define MAX_ROCKETS						100
#define MAX_ROCKET_CLASSES				50
#define MAX_SPAWNER_CLASSES				50
#define MAX_SPAWN_POINTS				100
#define PYROVISION_ATTRIBUTE 			"vision opt in flags"
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

//
// PD.3 #ENUMS
//
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

enum struct StealInfo {
	int rocketsStolen;
	bool stoleRocket;
}

StealInfo StealPlayer[MAXPLAYERS + 1];



//
// PD.4 #CONFIG VARS
//
Handle 	CVAR_AirBlastPrevention;
Handle 	CVAR_EnableCfgFile;
Handle 	CVAR_DisableCfgFile;
Handle 	CVAR_HudSpeedo;
Handle 	CVAR_AutoPyroVision = INVALID_HANDLE;
Handle 	CVAR_RedirectBeep;
Handle 	CVAR_PreventTauntKills;
Handle 	CVAR_StealPrevention;
Handle 	CVAR_StealPreventionCount;
Handle 	CVAR_DelayPrevention;
Handle 	CVAR_DelayPreventionTime;
Handle 	CVAR_MaxRocketBounces;
Handle 	CVAR_DelayPreventionSpeedup;



//
// PD.5 #GAMEPLAY VARS
//
bool 	G_TargetDied		[MAXPLAYERS + 1];
int 	G_FirstJoined		[MAXPLAYERS + 1];
bool 	G_VotedForNoDamage	[MAXPLAYERS + 1];
int 	G_Observer;
int		G_Op_Rocket;
int 	G_Bounces[MAX_EDICTS]; 		// Current Bounces of a specific Rocket
int 	G_MaxRocketBounces = 10000; // Maximum Bounces of all Rockets
bool 	G_PluginEnabled = 	false;	// If the Plugin is Enabled 
bool 	G_MapIsTFDB = 		false; 	// If the Map starts with 'tfdb'
bool 	G_RoundStarted = 	false;	// If the Round has Started 

bool 	G_NoDamage = 		false;	// If Damage to Players is Enabled
bool 	G_NoDamageVoted = 	false;	// If Enabling/Disabling Damage to Players was Voted
int 	G_NoDamageVoteTime = 0;		// Last Time a Vote started to enable/disable Damage to Players

int 	G_RoundCount = 		0; 		// Current Round Count
int 	G_RocketsFired = 	0; 		// Current Rockets Fired
float 	G_LastSpawnTime = 	0.0; 	// Last Rocket Spawn Time
float 	G_NextSpawnTime = 	0.0; 	// Next Rocket Spawn Time
int 	G_LastDeadTeam = 	0;		// Latest Team which died
int 	G_LastDeadClient = 	0; 		// Latest Client which died
int 	G_PlayerCount = 	0;		// Current Player Count
float 	G_LastRocketSpeed = 0.0;	// Latest Rocket Speed
Handle 	G_HudTimer;
Handle 	G_Hud;
Handle 	G_LogicTimer;
Handle 	G_NoDamageTimer;

//
// PD.6 #ROCKET VARS
// 
enum struct Rocket {
	bool isValid;
	bool isNuke;
	int entity;
	int target;
	int spawner;
	int class;
	RocketFlags flags;
	float speed;
	float direction[3];
	int deflections;
	float lastDeflectionTime;
	float lastBeepTime;
}
Rocket RINFO[MAX_ROCKETS];

int R_LastCreated;
bool R_PreventingDelay;
int R_Count;
float R_SavedSpeed;
float R_SavedSpeedIncrement;


//
// PD.7 #ROCKET CLASS VARS
//
enum struct RocketClass {
	char name[16];
	char longName[32];
	char savedClassName[32];
	char model[PLATFORM_MAX_PATH];
	RocketFlags flags;
	float beepInterval;
	char spawnSound[PLATFORM_MAX_PATH];
	char beepSound[PLATFORM_MAX_PATH];
	char alertSound[PLATFORM_MAX_PATH];
	float critChance;
	float damage;
	float damageIncrement;
	float speed;
	float speedIncrement;
	float turnRate;
	float turnRateIncrement;
	float elevationRate;
	float elevationLimit;
	float rocketModifier;
	float playerModifier;
	float controlDelay;
	float targetWeight;
	Handle commandsOnSpawn;
	Handle commandsOnDeflect;
	Handle commandsOnKill;
	Handle commandsOnExplode;
}
RocketClass RCLASS[MAX_ROCKET_CLASSES];
Handle 	RC_Trie;
char 	RC_Count;
char RC_SavedClassName[32];

//
// PD.8 #SPAWNER CLASS VARS
//
enum struct SpawnerClass {
	char name[32];
	int maxRockets;
	float interval;
	Handle chancesTable;
}
SpawnerClass SCLASS[MAX_SPAWNER_CLASSES];
Handle 	SC_Trie;
int SC_Count;
int SC_CurrentRedSpawn;
int SC_SpawnPointsRedCount;
int SC_CurrentBluSpawn;
int SC_SpawnPointsBluCount;
int SC_DefaultRedSpawner;
int SC_DefaultBluSpawner;

enum struct SpawnPointClass {
	int spawnPointsRedClass;
	int spawnPointsRedEntity;
	int spawnPointsBluClass;
	int spawnPointsBluEntity;
}
SpawnPointClass SPCLASS[MAX_SPAWN_POINTS];





//
// PD.9 #PLUGIN END/START
//
public Plugin myinfo =  {
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_NAME, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_CONTACT
};

 public void OnPluginStart() {
	if (!GameIsTF2())
		SetFailState("This plugin is only for Team Fortress 2.");
	RC_Trie = CreateTrie();
	SC_Trie = CreateTrie();
	G_Hud = CreateHudSynchronizer();
	manageConfig();
	manageCommands();
}

public void OnPluginEnd() {
	
}



//
// PD.10 #COMMANDS
//
/* PD.10:1 #ADMINMENU COMMAND */
public Action AdminMenuCommand(int iClient, int iArgs) {
	DrawAdminMenu(iClient);
	return Plugin_Handled;
}
void DrawAdminMenu(int client) {
	Menu menu = new Menu(AdminMenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("Dodgeball Admin Menu");
	menu.AddItem("0", "Max Rocket Count");
	menu.AddItem("1", "Speed Multiplier");
	menu.AddItem("2", "Main Rocket Class");
	menu.AddItem("3", "Refresh Configurations");
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
 public int AdminMenuHandler(Menu menu, MenuAction action, int iClient, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			switch (param2) {
				case 0:
				DrawMaxRocketCountMenu(iClient);
				case 1:
				DrawRocketSpeedMenu(iClient);
				case 2: {
					if (!RC_SavedClassName[0]) {
						CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}No main rocket class detected, aborting...");
						return;
					}
					DrawRocketClassMenu(iClient);
				}
				case 3: {
					DestroyRocketClasses();
					DestroySpawners();
					char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
					char strMapFile[PLATFORM_MAX_PATH]; Format(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
					ParseConfigurations("general.cfg");
					ParseConfigurations(strMapFile);
					CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}You refreshed the Dodgeball configs.");
				}
			}
		}
		case MenuAction_Cancel:
			PrintToServer("Client %d's menu was cancelled for reason %d", iClient, param2); // Logging once again.
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
/**
 * Start Max Rocket Count Menu
 */
public void DrawMaxRocketCountMenu(int iClient) {
	Menu menu = new Menu(MaxRocketCountMenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("How many rockets?");
	menu.AddItem("0", "One");
	menu.AddItem("1", "Two");
	menu.AddItem("2", "Three");
	menu.AddItem("3", "Four");
	menu.AddItem("4", "Five");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public void SetMaxRocketCount(int iCount) {
	int iSpawnerClassBlu = SPCLASS[SC_CurrentBluSpawn].spawnPointsBluClass;
	int iSpawnerClassRed = SPCLASS[SC_CurrentRedSpawn].spawnPointsRedClass;
	SCLASS[iSpawnerClassBlu].maxRockets = iCount;
	SCLASS[iSpawnerClassRed].maxRockets = iCount;
}
public int MaxRocketCountMenuHandler(Menu menu, MenuAction action, int iClient, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			switch (param2) {
				case 0: {
					SetMaxRocketCount(1);
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}1{default}.", iClient);
				}
				case 1: {
					SetMaxRocketCount(2);
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}2{default}.", iClient);
				}
				case 2: {
					SetMaxRocketCount(3);
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}3{default}.", iClient);
				}
				case 3: {
					SetMaxRocketCount(4);
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}4{default}.", iClient);
				}
				case 4: {
					SetMaxRocketCount(5);
					CPrintToChatAll("{mediumpurple}%N{default} changed the max rockets to {dodgerblue}5{default}.", iClient);
				}
			}
		}
		case MenuAction_Cancel: {
			delete menu;
			if (param2 == MenuCancel_ExitBack)
				DrawAdminMenu(iClient);
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
/**
 * End Max Rocket Count Menu
 */

/**
 * Start Rocket Speed Menu
 */
void DrawRocketSpeedMenu(int iClient) {
	Menu menu = new Menu(RocketSpeedMenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("How fast should the rockets go?");
	menu.AddItem("0", "50% (Slow)");
	menu.AddItem("1", "75% (Slower)");
	menu.AddItem("2", "100% (Normal)");
	menu.AddItem("3", "125% (Faster)");
	menu.AddItem("4", "150% (Fast)");
	menu.AddItem("5", "175% (Even Faster)");
	menu.AddItem("6", "200% (Silly Fast)");
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public void SetRocketSpeed(float fMultiply) {
	float newSpeed = R_SavedSpeed;
	float newSpeedIncrement = R_SavedSpeedIncrement;
	int iSpawnerClassBlu = SPCLASS[SC_CurrentBluSpawn].spawnPointsBluClass;
	int iSpawnerClassRed = SPCLASS[SC_CurrentRedSpawn].spawnPointsRedClass;
	int iClassRed = GetRandomRocketClass(iSpawnerClassRed);
	int iClassBlu = GetRandomRocketClass(iSpawnerClassBlu);
	RCLASS[iClassRed].speed = newSpeed * fMultiply;
	RCLASS[iClassRed].speedIncrement = newSpeedIncrement * fMultiply;
	RCLASS[iClassBlu].speed = newSpeed * fMultiply;
	RCLASS[iClassBlu].speedIncrement = newSpeedIncrement * fMultiply;

}
public int RocketSpeedMenuHandler(Menu menu, MenuAction action, int iClient, int param2) {
	switch (action) {
		case MenuAction_Display:
			PrintToServer("Client %d was sent menu with panel %x", iClient, param2); // Log so you can check if it gets sent.
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			switch (param2) {
				case 0: {
					SetRocketSpeed(0.5);
					CPrintToChatAll("{mediumpurple}%N{default} changed the rocket speed to{dodgerblue} 50%%{default} (Slow)", iClient);
				}
				case 1: {
					SetRocketSpeed(0.75);
					CPrintToChatAll("{mediumpurple}%N{default} changed the rocket speed to {dodgerblue}75%%{default} (Slower)", iClient);
				}
				case 2: {
					SetRocketSpeed(1.0);
					CPrintToChatAll("{mediumpurple}%N{default} changed the rocket speed to {dodgerblue} 100%%{default} (Normal)", iClient);			
				}
				case 3: {
					SetRocketSpeed(1.25);
					CPrintToChatAll("{mediumpurple}%N {default} changed the rocket speed to {dodgerblue}125%%{default} (Faster)", iClient);
				}
				case 4: {
					SetRocketSpeed(1.5);
					CPrintToChatAll("{mediumpurple}%N {default} changed the rocket speed to {dodgerblue}150%%{default} (Fast)", iClient);
				}
				case 5: {
					SetRocketSpeed(1.75);
					CPrintToChatAll("{mediumpurple}%N {default} changed the rocket speed to {dodgerblue}175%%{default} (Even Faster)", iClient);
				}
				case 6: {
					SetRocketSpeed(2.0);
					CPrintToChatAll("{mediumpurple}%N {default} changed the rocket speed to {dodgerblue}200%%{default} (Silly Faster)", iClient);
				}
			}
		}
		case MenuAction_Cancel: {
			delete menu;
			if (param2 == MenuCancel_ExitBack)
				DrawAdminMenu(iClient);
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
/**
 * End Rocket Speed Menu
 */

/**
 * Start Rocket Class Menu
 */
public void DrawRocketClassMenu(int iClient) {
	Menu menu = new Menu(RocketClassMenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("Which class should the rocket be set to?");
	for (int currentClass = 0; currentClass < RC_Count; currentClass++) {
		char classNumber[16];
		IntToString(currentClass, classNumber, sizeof(classNumber));
		if (StrEqual(RC_SavedClassName, RCLASS[currentClass].longName)) {
			char currentClassName[32];
			strcopy(currentClassName, sizeof(currentClassName), "[Current] ");
			StrCat(currentClassName, sizeof(currentClassName), RC_SavedClassName);
			menu.AddItem(classNumber, currentClassName);
		} else menu.AddItem(classNumber, RCLASS[currentClass].longName);
	}
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(iClient, MENU_TIME_FOREVER);
}
public int RocketClassMenuHandler(Menu menu, MenuAction action, int iClient, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			SetMainRocketClass(param2, iClient);
		}
		case MenuAction_Cancel: {
			delete menu;
			if (param2 == MenuCancel_ExitBack)
				DrawAdminMenu(iClient);
		}
		case MenuAction_End: {
			delete menu;
		}
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
/**
 * End Rocket Class Menu
 */

/* PD.10:2 #AIRBLAST COMMAND */
public Action AirBlastCommand(int iClient, int iArgs) {
	if (!G_MapIsTFDB)
		return Plugin_Handled;
	if (GetConVarBool(CVAR_AirBlastPrevention)) {
		preventAirblast(iClient, true);
		CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}If AirBlast Prevention was disabled, then it is now enabled.");
	} else {
		CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}AirBlast Prevention is disabled on this Server.");
	}
	return Plugin_Handled;
}

/* PD.10:3 #CURRENTROCKET COMMAND */
public Action CurrentRocketCommand(int iClient, int iArgs) {
	if (!RC_SavedClassName[0]) {
		CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}Current Rocket: {dodgerblue}Multiple{default}");
		return Plugin_Handled;
	}
	CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}Current Rocket: {dodgerblue}%s{default}", RC_SavedClassName);
	return Plugin_Handled;
}

/* PD.10:4 #SHOCKWAVE COMMAND */
public Action ShockWaveCommand(int iArgs) {
	if (!G_PluginEnabled || !G_MapIsTFDB) {
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

/* PD.10:5 #EXPLOSION COMMAND */
public Action ExplosionCommand(int iArgs) {
	if (!G_PluginEnabled || !G_MapIsTFDB) {
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

/* PD.10:6 #RESIZE COMMAND */
public Action ResizeCommand(int iIndex) {
	if (!G_PluginEnabled || !G_MapIsTFDB) {
		PrintToServer("Cannot use command. Dodgeball is disabled.");
		return Plugin_Handled;
	}
	int iEntity = EntRefToEntIndex(RINFO[iIndex].entity);
	if (iEntity && IsValidEntity(iEntity) && RINFO[iEntity].isNuke) {
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", (4.0));
	}
	return Plugin_Handled;
}

/* PD.10:7 #VOTENODAMAGE COMMAND */
public Action VoteNoDamageCommand(int iClient, int args) {
	if (!G_MapIsTFDB)
		return Plugin_Handled;
		
	/* Check if a new Vote can be started already */
	int iTime =  GetTime() - G_NoDamageVoteTime;
	if (iTime >= 180) {
		/* Check if the Player already voted */
		if (G_VotedForNoDamage[iClient] == false) {
			
			/* Get Data ... */
			G_VotedForNoDamage[iClient] = true;
			int iVoteCount = GetNoDamageVoteCount();
			int iRatio = RoundToNearest((GetValidTeamClientCount(2) + GetValidTeamClientCount(3)) * 0.6);
			int voteMinimum = RoundToNearest(CountPlayers(false) * 0.5);
			if (iRatio < voteMinimum)
				iRatio = voteMinimum;
	
			/* Print Messages to Everyone that Somebody Voted for Enabling/Disabling */
			if (G_NoDamage)
				CPrintToChatAll("{mediumpurple}%N{default} voted for enabling Damage to Players {black}[{dodgerblue}%i{default}/{dodgerblue}%i{black}]", iClient, iVoteCount, iRatio);
			else
				CPrintToChatAll("{mediumpurple}%N{default} voted for disabling Damage to Players {black}[{dodgerblue}%i{default}/{dodgerblue}%i{black}]", iClient, iVoteCount, iRatio);
			
			/* If the executer was the last one reach the goal; Print Messages, Enable/Disable Next Round, Reset Voting*/ 
			if (iVoteCount >= iRatio) {
				if (G_NoDamage) {
					CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {default}Enough votes recieved! Enabling Damage to Players next Round or 30 Seconds.");
					G_NoDamage = false;
					
				} else { 
					CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {default}Enough votes recieved! Disabling Damage to Players next Round or 30 Seconds.");
					G_NoDamage = true;
				}
				G_NoDamageTimer = CreateTimer(30.0, VoteNoDamageTimed);
				G_NoDamageVoted = true;
				G_NoDamageVoteTime = GetTime();
				for(int i = 1; i <= MaxClients; i++) if(IsValidClient(i))
					G_VotedForNoDamage[i] = false;
			}
		} else {
			CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}You already voted.");
		}
	} else {
		CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}You have to wait {dodgerblue}%i{default} more Seconds before you can use this Command again.", (180 - iTime));
	}
	return Plugin_Handled;
}
int GetNoDamageVoteCount() {
	int iCount;
	for(int i = 1; i <= MaxClients; i++) if(IsValidClient(i)) {
		if(G_VotedForNoDamage[i])
			iCount++;
	}
	return iCount;
}
int GetValidTeamClientCount(int iTeam){
	int iCount;
	for(int i = 1; i <= MaxClients; i++) if(IsValidClient(i)) {
		if(GetClientTeam(i) == iTeam)
			iCount++;
	}
	return iCount;
}

public Action VoteNoDamageTimed(Handle hTimer) {
	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (IsValidClient(iClient, false)) {
			if (G_NoDamage) {
				ServerCommand("sakagod %i 1", GetClientUserId(iClient));
			} else {
				ServerCommand("sakagod %i 0", GetClientUserId(iClient));
			}
		}
	}
}
//
// PD.11 #EVENTS
//
/* PD.11:1 #ObjectDeflectedEvent */
public Action ObjectDeflectedEvent(Handle hEvent, const char[] name, bool dontBroadcast) {
	if (!G_MapIsTFDB) {
		return;
	}
	int iClient = GetEventInt(hEvent, "userid");
	int iClientID = GetClientOfUserId(iClient);
	int iIndex = GetEventInt(hEvent, "object_entindex");
	float fSpeed = RINFO[FindRocketByEntity(iIndex)].speed;
	// Check if current rocket speed is higher then highest speed before (in STATS plugin)
	if (!IsFakeClient(iClientID))
		ServerCommand("sakastats updatetopspeed %i %.0f", iClientID, fSpeed);
	
	/*if (GetConVarBool(CVAR_AirBlastPrevention)) {
		CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {default}DEV-LOG - iClient %i / iIndex %i / clientID %i", iClient, iIndex, iClientID);
		float Vel[3];
		CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {default}DEV-LOG - Valid Entity");
		TeleportEntity(iClientID, NULL_VECTOR, NULL_VECTOR, Vel); //Stops knockback
		if (IsClientInGame(iClientID)) {
			TF2_RemoveCondition(iClientID, TFCond_Dazed); // Stops slowdown 
		}
			
		SetEntPropVector(iClientID, Prop_Send, "m_vecPunchAngle", Vel);
		SetEntPropVector(iClientID, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake
	}*/
}

/* PD.11:2 #PlayerSpawnEvent */
public Action PlayerSpawnEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!G_MapIsTFDB || !IsValidClient(iClient))
		return;
	G_TargetDied[iClient] = false;
	StealPlayer[iClient].rocketsStolen = 0;
	
	
	/* Setting Pyro as Class*/
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	if (!(iClass == TFClass_Pyro || iClass == view_as<TFClassType>(TFClass_Unknown))) {
		TF2_SetPlayerClass(iClient, TFClass_Pyro, false, true);
		TF2_RespawnPlayer(iClient);
	}
	/* Enable only Primary Weapon */
	for (int i = MaxClients; i; --i) {
		if (IsClientInGame(i) && IsPlayerAlive(i))
			SetEntPropEnt(i, Prop_Data, "m_hActiveWeapon", GetPlayerWeaponSlot(i, TFWeaponSlot_Primary));
	}
	/* Setting PyroVision */
	if (GetConVarBool(CVAR_AutoPyroVision))
		TF2Attrib_SetByName(iClient, PYROVISION_ATTRIBUTE, 1.0);
		
	/* Check if it's enabled; Then AirBlast Prevention */
	if (GetConVarBool(CVAR_AirBlastPrevention))
		preventAirblast(iClient, true);
}

/* PD.11:3 #PlayerDeathEvent */
public Action PlayerDeathEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (!G_MapIsTFDB)
		return;
	/* Reset First Joined for the next Spawn event*/
	G_FirstJoined[iVictim] = false;
	if (IsValidClient(iVictim)) {
		if (GetConVarBool(CVAR_StealPrevention)) {
			StealPlayer[iVictim].stoleRocket = false;
			StealPlayer[iVictim].rocketsStolen = 0;
		}
		G_LastDeadClient = iVictim;
		G_LastDeadTeam = GetClientTeam(iVictim);
		
		int iInflictor = GetEventInt(hEvent, "inflictor_entindex");
		int iIndex = FindRocketByEntity(iInflictor);
		
		if (iIndex != -1) {
			G_TargetDied[iVictim] = true;
			int iClass = RINFO[iIndex].class;
			int iTarget = EntRefToEntIndex(RINFO[iIndex].target);
			int iDeflections = RINFO[iIndex].deflections;
			float fSpeed = CalculateSpeed(RINFO[iIndex].speed);
			float fAdminSpeed = RINFO[iIndex].speed;
			if (iVictim == iTarget) {
				CPrintToChatAll("{mediumpurple}%N{default} died to {dodgerblue}%.0f{default} mph ({dodgerblue}%i{default} Deflections | {dodgerblue}%.0f{default} Admin Speed)", iVictim, fSpeed, iDeflections, fAdminSpeed);
			} else {
				CPrintToChatAll("{mediumpurple}%N{default} died to {dodgerblue}%.15N's{default} rocket: {mediumpurple}%.0f{default} mph ({dodgerblue}%i{default} Deflections | {dodgerblue}%.0f{default} Admin Speed)", iVictim, iTarget, fSpeed, iDeflections, fAdminSpeed);
			}
			if ((RINFO[iIndex].flags & RocketFlag_OnExplodeCmd) && !(RINFO[iIndex].flags & RocketFlag_Exploded)) {
				ExecuteCommands(RCLASS[iClass].commandsOnExplode, iClass, iInflictor, iAttacker, iTarget, G_LastDeadClient, fSpeed, iDeflections);
				RINFO[iIndex].flags |= RocketFlag_Exploded;
			}
			if (TestFlags(RINFO[iIndex].flags, RocketFlag_OnKillCmd))
				ExecuteCommands(RCLASS[iClass].commandsOnKill, iClass, iInflictor, iAttacker, iTarget, G_LastDeadClient, fSpeed, iDeflections);
		}
	}
	SetRandomSeed(view_as<int>(GetGameTime()));
}

/* PD.11:4 #SetupFinishedEvent */
public Action SetupFinishedEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if ((G_PluginEnabled && G_MapIsTFDB) && (BothTeamsPlaying() == true)) {
		PopulateSpawnPoints();
		
		if (G_LastDeadTeam == 0)
			G_LastDeadTeam = GetURandomIntRange(view_as<int>(TFTeam_Red), view_as<int>(TFTeam_Blue));
		if (!IsValidClient(G_LastDeadClient))
			G_LastDeadClient = 0;
		
		G_LogicTimer = CreateTimer(FPS_LOGIC_INTERVAL, OnDodgeBallGameFrame, _, TIMER_REPEAT);
		G_PlayerCount = CountPlayers(true);
		G_RocketsFired = 0;
		SC_CurrentRedSpawn = 0;
		SC_CurrentBluSpawn = 0;
		G_NextSpawnTime = GetGameTime();
		G_RoundStarted = true;
		G_RoundCount++;

	}
}

/* PD.11:5 #PlayerPostInventoryEvent */
public Action PlayerPostInventoryEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!G_MapIsTFDB)
		return;	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(iClient))return;
	
	for (int iSlot = 1; iSlot < 5; iSlot++) {
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity != -1)RemoveEdict(iEntity);
	}
}

/* PD.11:6 #RoundStartEvent */
public Action RoundStartEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	/* Check if it's a TFDB Map '*/
	if (!G_MapIsTFDB)
		return;
	/* Automatically Set NoDamage to true if Only 2 Players on the Server & No Damage isn't Voted via CMD'*/
	int iCountPlayersAlive = CountPlayers(true);
	CPrintToChatAll("STARTING SETUP");
	if (iCountPlayersAlive <= 2) {
		G_NoDamage = true;
		for (int iClient = 0; iClient <= MaxClients; iClient++)
			if (IsValidClient(iClient, true))
				ServerCommand("sakagod %i 0", iClient);
			
				
	}
		
	
	/* Check if NoDamage is Enabled & a min. of 2 Players Online [ENABLED] */
	if (CountPlayers(true) > 2 && G_NoDamage)
		for (int iClient = 0; iClient <= MaxClients; iClient++)
			if (IsValidClient(iClient, true))
				ServerCommand("sakagod %i 1", iClient);
				//CPrintToChatAll("TEST #3 ALIVE %i BOOL %b CLIENT %N %i %i", CountAlivePlayers(), G_NoDamage, iClient, iClient, GetClientUserId(iClient)); 
	/* Check if NoDamage is Disabled & it was Voted [DISABLED] */				
	if (G_NoDamageVoted && !G_NoDamage)
		for (int iClient = 0; iClient <= MaxClients; iClient++)
			if (IsValidClient(iClient, true))
				ServerCommand("sakagod %i 0", iClient);
	
	if (GetConVarBool(CVAR_StealPrevention)) {
		for (int iClient = 0; iClient <= MaxClients; iClient++) {
			StealPlayer[iClient].stoleRocket = false;
			StealPlayer[iClient].rocketsStolen = 0;
		}
	}
	G_LastRocketSpeed = 0.0;
	if (G_HudTimer != INVALID_HANDLE) {
		KillTimer(G_HudTimer);
		G_HudTimer = INVALID_HANDLE;
	}
	G_HudTimer = CreateTimer(1.0, Timer_HudSpeed, _, TIMER_REPEAT);
}

/* PD.11:7 #RoundEndEvent */
public Action RoundEndEvent(Handle hEvent, char[] strEventName, bool bDontBroadcast) {
	if (!G_MapIsTFDB)
		return;
	
	if (G_HudTimer != INVALID_HANDLE) {
		KillTimer(G_HudTimer);
		G_HudTimer = INVALID_HANDLE;
	}
	if (G_LogicTimer != INVALID_HANDLE) {
		KillTimer(G_LogicTimer);
		G_LogicTimer = INVALID_HANDLE;
	}
	
	for (int i = 0; i < MAXPLAYERS + 1; i++)
		G_FirstJoined[i] = false;
	
	DestroyRockets();
	G_RoundStarted = false;
}



//
// PD.12 #SOURCE MOD EVENTS
//
/* PD.12:1 #OnMapStart */
public void OnMapStart() {
	G_MapIsTFDB = IsDodgeballMap();
	if (G_MapIsTFDB)
		EnableDodgeBall();
}

/* PD.12:2 #OnConfigsExecuted */
public void OnConfigsExecuted() {}

/* PD.12:3 #OnConfigsExecuted */
public void OnMapEnd() {
	DisableDodgeBall();
}

/* PD.12:4 #OnClientPutInServer */
public void OnClientPutInServer(int clientId) {
	if (!G_MapIsTFDB)
		return;
	G_FirstJoined[clientId] = true;
	if (CountPlayers(false) => 3) {
		for (int iClient = 0; iClient <= MaxClients; iClient++)
			if (IsValidClient(iClient, false))
				ServerCommand("sakagod %i 1", iClient);
	}
	if (GetConVarBool(CVAR_PreventTauntKills))
		SDKHook(clientId, SDKHook_OnTakeDamage, TauntCheck);
}

/* PD.12:5 #OnClientDisconnect */
public void OnClientDisconnect(int iClient) {
	if (!G_MapIsTFDB)
		return;
	if (2 > CountPlayers(true)) {
		G_NoDamageVoted = false;
	}
	if (GetConVarBool(CVAR_PreventTauntKills))
		SDKUnhook(iClient, SDKHook_OnTakeDamage, TauntCheck);
	if (GetConVarBool(CVAR_StealPrevention)) {
		StealPlayer[iClient].stoleRocket = false;
		StealPlayer[iClient].rocketsStolen = 0;
	}
}

/* PD.12:6 #OnPlayerRunCmd */
public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon) {
	if (G_PluginEnabled && G_MapIsTFDB) iButtons &= ~IN_ATTACK;
	return Plugin_Continue;
}

/* PD.12:7 #OnEntityDestroyed */
public void OnEntityDestroyed(int entity) {
	
	if (!G_MapIsTFDB)
		return;
	if (entity == -1) {
		return;
	}
	if (IsValidRocket(FindRocketByEntity(entity)) && G_LastRocketSpeed >= 35) {
		int iRocket = FindRocketByEntity(entity);
		int iTarget = EntRefToEntIndex(RINFO[iRocket].target);
		if (!G_TargetDied[iTarget]) {
			CPrintToChatAll("{mediumpurple}%N {black}: {dodgerblue}%.0f{default} mph ({dodgerblue}%i{default} Deflections | {dodgerblue}%.0f{default} Admin Speed)", iTarget, G_LastRocketSpeed, RINFO[iRocket].deflections, RINFO[iRocket].speed);
		}
	}
	
	if (entity == G_Op_Rocket && G_PluginEnabled && IsValidEntity(G_Observer) && IsValidEntity(G_Op_Rocket)) {
		SetVariantString("");
		AcceptEntityInput(G_Observer, "ClearParent");
		G_Op_Rocket = -1;
		
		float opPos[3];
		float opAng[3];
		
		int spawner = GetRandomInt(0, 1);
		if (spawner == 0)
			spawner = SPCLASS[0].spawnPointsRedEntity;
		else
			spawner = SPCLASS[0].spawnPointsBluEntity;
		
		if (IsValidEntity(spawner) && spawner > MAXPLAYERS) {
			GetEntPropVector(spawner, Prop_Data, "m_vecOrigin", opPos);
			GetEntPropVector(spawner, Prop_Data, "m_angAbsRotation", opAng);
			TeleportEntity(G_Observer, opPos, opAng, NULL_VECTOR);
		}
	}
}


//
// PD.13 #GAMEPLAY FUNCTIONS
//
/* PD.13:1 #IsDodgeballMap */
bool IsDodgeballMap() {
	char strMap[64];
	GetCurrentMap(strMap, sizeof(strMap));
	return StrContains(strMap, "tfdb_", false) == 0;
}

/* PD.13:2 #GameIsTF2 */
bool GameIsTF2() {
	char strModName[32]; GetGameFolderName(strModName, sizeof(strModName));
	return StrEqual(strModName, "tf");
}

/* PD.13:3 #manageCommands */
void manageCommands() {
	RegAdminCmd("sm_currentrocket", CurrentRocketCommand, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_votenodamage", VoteNoDamageCommand);
	RegConsoleCmd("sm_vnd", VoteNoDamageCommand);
	RegServerCmd("sakadb_explosion", ExplosionCommand);
	RegServerCmd("sakadb_shockwave", ShockWaveCommand);
	RegServerCmd("sakadb_resize", ResizeCommand);
	RegAdminCmd("sm_tfdb", AdminMenuCommand, ADMFLAG_GENERIC, "A menu for admins to modify things inside the plugin.");
	RegAdminCmd("sm_ab", AirBlastCommand, ADMFLAG_GENERIC, "Toggles AirBlast Prevention on the Server");
	ServerCommand("tf_arena_use_queue 0");
}

/* PD.13:4 #manageEvents */
void manageEvents(bool hook) {
	if (hook) {
		HookEvent("object_deflected", ObjectDeflectedEvent);
		HookEvent("teamplay_round_start", RoundStartEvent, EventHookMode_PostNoCopy);
		HookEvent("teamplay_setup_finished", SetupFinishedEvent, EventHookMode_PostNoCopy);
		HookEvent("teamplay_round_win", RoundEndEvent, EventHookMode_PostNoCopy);
		HookEvent("player_spawn", PlayerSpawnEvent, EventHookMode_Post);
		HookEvent("player_death", PlayerDeathEvent, EventHookMode_Pre);
		HookEvent("post_inventory_application", PlayerPostInventoryEvent, EventHookMode_Post);
	} else {
		UnhookEvent("object_deflected", ObjectDeflectedEvent);
		UnhookEvent("teamplay_round_start", RoundStartEvent, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_setup_finished", SetupFinishedEvent, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", RoundEndEvent, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", PlayerSpawnEvent, EventHookMode_Post);
		UnhookEvent("player_death", PlayerDeathEvent, EventHookMode_Pre);
		UnhookEvent("post_inventory_application", PlayerPostInventoryEvent, EventHookMode_Post);
	}
}

/* PD.13:5 #manageConfig */
void manageConfig() {
	CreateConVar("sakadb_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY | FCVAR_UNLOGGED | FCVAR_DONTRECORD | FCVAR_REPLICATED | FCVAR_NOTIFY);
	CVAR_AirBlastPrevention = CreateConVar("sakadb_airblast_prevention", "1", "Is Air Blast Prevention Enabled (1=YES;2=NO)");
	CVAR_EnableCfgFile = CreateConVar("sakadb_enablecfg", "sourcemod/dodgeball_enable.cfg", "Config file to execute when enabling the Dodgeball game mode.");
	CVAR_DisableCfgFile = CreateConVar("sakadb_disablecfg", "sourcemod/dodgeball_disable.cfg", "Config file to execute when disabling the Dodgeball game mode.");
	CVAR_HudSpeedo = CreateConVar("sakadb_hudspeedo", "1", "Enable HUD speedometer");
	CVAR_AutoPyroVision = CreateConVar("sakadb_autopyrovision", "1", "Enable pyrovision for everyone");
	CVAR_MaxRocketBounces = CreateConVar("sakadb_maxrocketbounce", "10000", "Max number of times a rocket will bounce.", FCVAR_NONE, true, 0.0, false);
	CVAR_RedirectBeep = CreateConVar("sakadb_redirectbeep", "1", "Do redirects beep?");
	CVAR_PreventTauntKills = CreateConVar("sakadb_block_tauntkill", "0", "Block taunt kills?");
	CVAR_StealPrevention = CreateConVar("sakadb_steal_prevention", "0", "Enable steal prevention?");
	CVAR_StealPreventionCount = CreateConVar("sakadb_sp_count", "3", "How many steals before you get slayed?");
	CVAR_DelayPrevention = 	CreateConVar("sakadb_delay_prevention", "0", "Enable delay prevention?");
	CVAR_DelayPreventionTime = 	CreateConVar("sakadb_dp_time", "5", "How much time (in seconds) before delay prevention activates?", FCVAR_NONE, true, 0.0, false);
	CVAR_DelayPreventionSpeedup = CreateConVar("sakadb_dp_speedup", "100", "How much speed (in hammer units per second) should the rocket gain (20 Refresh Rate for every 0.1 seconds) for delay prevention? Multiply by (15/352) for mph.", FCVAR_NONE, true, 0.0, false);
	AutoExecConfig(true, "sakadodgeball");
	HookConVarChange(CVAR_MaxRocketBounces, tf2dodgeball_hooks);
	HookConVarChange(CVAR_AutoPyroVision, tf2dodgeball_hooks);
}

/* PD.13:6 #EnableDodgeball */
void EnableDodgeBall() {
	if (!G_PluginEnabled) {
		/* Parse Map Config and other Config's' */
		char strMapName[64]; GetCurrentMap(strMapName, sizeof(strMapName));
		char strMapFile[PLATFORM_MAX_PATH]; Format(strMapFile, sizeof(strMapFile), "%s.cfg", strMapName);
		ParseConfigurations("general.cfg");
		ParseConfigurations(strMapFile);
		
		ServerCommand("sakadb_maxrocketbounce %f", GetConVarFloat(CVAR_MaxRocketBounces));
		if (RC_Count == 0)
			SetFailState("No rocket class defined.");
		if (SC_Count == 0)
			SetFailState("No spawner class defined.");
		if (SC_DefaultRedSpawner == -1)
			SetFailState("No spawner class definition for the Red spawners exists in the config file.");
		if (SC_DefaultBluSpawner == -1)
			SetFailState("No spawner class definition for the Blu spawners exists in the config file.");
		manageEvents(true);
		/* Precache Sound, Particles & Rocket Resources*/
		PrecacheSound(SOUND_DEFAULT_SPAWN, true);
		PrecacheSound(SOUND_DEFAULT_BEEP, true);
		PrecacheSound(SOUND_DEFAULT_ALERT, true);
		PrecacheSound(SOUND_DEFAULT_SPEEDUPALERT, true);
		PrecacheParticle(PARTICLE_NUKE_1);
		PrecacheParticle(PARTICLE_NUKE_2);
		PrecacheParticle(PARTICLE_NUKE_3);
		PrecacheParticle(PARTICLE_NUKE_4);
		PrecacheParticle(PARTICLE_NUKE_5);
		PrecacheParticle(PARTICLE_NUKE_COLLUMN);
		for (int i = 0; i < RC_Count; i++) {
			RocketFlags iFlags = RCLASS[i].flags;
			if (TestFlags(iFlags, RocketFlag_CustomModel))PrecacheModelEx(RCLASS[i].model, true, true);
			if (TestFlags(iFlags, RocketFlag_CustomSpawnSound))PrecacheSoundEx(RCLASS[i].spawnSound, true, true);
			if (TestFlags(iFlags, RocketFlag_CustomBeepSound))PrecacheSoundEx(RCLASS[i].beepSound, true, true);
			if (TestFlags(iFlags, RocketFlag_CustomAlertSound))PrecacheSoundEx(RCLASS[i].alertSound, true, true);
		}
		
		// Execute enable config file
		char strCfgFile[64]; GetConVarString(CVAR_EnableCfgFile, strCfgFile, sizeof(strCfgFile));
		ServerCommand("exec \"%s\"", strCfgFile);
		
		// Done.
		G_PluginEnabled = true;
		G_RoundStarted = false;
		G_RoundCount = 0;
		G_NoDamageVoted = false;
	}
}

/* PD.13:7 #DisableDodgeball */
void DisableDodgeBall() {
	if (G_PluginEnabled == true) {
		DestroyRockets();
		DestroyRocketClasses();
		DestroySpawners();
		if (G_LogicTimer != INVALID_HANDLE)
			KillTimer(G_LogicTimer);
		G_LogicTimer = INVALID_HANDLE;
		if (G_NoDamageTimer != INVALID_HANDLE)
			KillTimer(G_NoDamageTimer);
		G_NoDamageTimer = INVALID_HANDLE;
		manageEvents(false);
		char strCfgFile[64]; GetConVarString(CVAR_DisableCfgFile, strCfgFile, sizeof(strCfgFile));
		ServerCommand("exec \"%s\"", strCfgFile);
		G_PluginEnabled = false;
		G_RoundStarted = false;
		G_RoundCount = 0;
		R_Count = 0;
	}
}



public Action Timer_HudSpeed(Handle hTimer) {
	if (GetConVarBool(CVAR_HudSpeedo) && G_MapIsTFDB) {
		SetHudTextParams(-1.0, 0.9, 1.1, 255, 255, 255, 255);
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsValidClient(iClient) && !IsFakeClient(iClient) && G_LastRocketSpeed != 0.0)
			ShowSyncHudText(iClient, G_Hud, "Speed: %.0f mph", G_LastRocketSpeed);
	}
}

public Action OnDodgeBallGameFrame(Handle hTimer, any Data) {
	if (!G_MapIsTFDB)
		return;
	
	// Only if both teams are playing
	if (BothTeamsPlaying() == false)
		return;
	
	// Check if we need to fire more rockets.
	if (GetGameTime() >= G_NextSpawnTime) {
		if (G_LastDeadTeam == view_as<int>(TFTeam_Red)) {
			int iSpawnerEntity = SPCLASS[SC_CurrentRedSpawn].spawnPointsRedEntity;
			int iSpawnerClass = SPCLASS[SC_CurrentRedSpawn].spawnPointsRedClass;
			if (R_Count < SCLASS[iSpawnerClass].maxRockets) {
				CreateRocket(iSpawnerEntity, iSpawnerClass, view_as<int>(TFTeam_Red));
				SC_CurrentRedSpawn = (SC_CurrentRedSpawn + 1) % SC_SpawnPointsRedCount;
			}
		} else {
			int iSpawnerEntity = SPCLASS[SC_CurrentBluSpawn].spawnPointsBluEntity;
			int iSpawnerClass = SPCLASS[SC_CurrentBluSpawn].spawnPointsBluClass;
			if (R_Count < SCLASS[iSpawnerClass].maxRockets) {
				CreateRocket(iSpawnerEntity, iSpawnerClass, view_as<int>(TFTeam_Blue));
				SC_CurrentBluSpawn = (SC_CurrentBluSpawn + 1) % SC_SpawnPointsBluCount;
			}
		}
	}
	
	// Manage the active rockets
	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1) {
		HomingRocketThink(iIndex); 
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



//
// PD.14 #ROCKET FUNCTIONS
//
/* PD.14:1 #CreateRocket */
public void CreateRocket(int iSpawnerEntity, int iSpawnerClass, int iTeam) {
	int iIndex = FindFreeRocketSlot();
	if (iIndex != -1) {
		// Fetch a random rocket class and it's parameters.
		int iClass = GetRandomRocketClass(iSpawnerClass);
		RocketFlags iFlags = RCLASS[iClass].flags;
		
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
			SetEntProp(iEntity, Prop_Send, "m_bCritical", (GetURandomFloatRange(0.0, 100.0) <= RCLASS[iClass].critChance) ? 1 : 0, 1);
			SetEntProp(iEntity, Prop_Send, "m_iTeamNum", iTeam, 1);
			SetEntProp(iEntity, Prop_Send, "m_iDeflected", 1);
			TeleportEntity(iEntity, fPosition, fAngles, view_as<float>( { 0.0, 0.0, 0.0 } ));
			
			// Setup rocket structure with the newly created entity.
			int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
			int iTarget = SelectTarget(iTargetTeam);
			float fModifier = CalculateModifier(iClass, 0);
			RINFO[iIndex].isValid = true;
			RINFO[iIndex].flags = iFlags;
			RINFO[iIndex].entity = EntIndexToEntRef(iEntity);
			RINFO[iIndex].target = EntIndexToEntRef(iTarget);
			RINFO[iIndex].spawner = iSpawnerClass;
			RINFO[iIndex].class = iClass;
			RINFO[iIndex].deflections = 0;
			RINFO[iIndex].lastDeflectionTime = GetGameTime();
			RINFO[iIndex].lastBeepTime = GetGameTime();
			RINFO[iIndex].speed = CalculateRocketSpeed(iClass, fModifier);
			G_LastRocketSpeed = CalculateSpeed(RINFO[iIndex].speed);
		 	
			CopyVectors(fDirection, RINFO[iIndex].direction);
			SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(iClass, fModifier), true);
			DispatchSpawn(iEntity);
			
			// Apply custom model, if specified on the flags.
			if (TestFlags(iFlags, RocketFlag_CustomModel)) {
				SetEntityModel(iEntity, RCLASS[iClass].model);
				UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
			}
			
			// Execute commands on spawn.
			if (TestFlags(iFlags, RocketFlag_OnSpawnCmd)) {
				ExecuteCommands(RCLASS[iClass].commandsOnSpawn, iClass, iEntity, 0, iTarget, G_LastDeadClient, RINFO[iIndex].speed, 0);
			}
			
			// Emit required sounds.
			EmitRocketSound(RocketSound_Spawn, iClass, iEntity, iTarget, iFlags);
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
			
			// Done
			R_Count++;
			G_RocketsFired++;
			G_LastSpawnTime = GetGameTime();
			G_NextSpawnTime = GetGameTime() + SCLASS[iSpawnerClass].interval;
			RINFO[iIndex].isValid = false;
			
			//AttachParticle(iEntity, "burningplayer_rainbow_glow");
			//AttachParticle(iEntity, "burningplayer_rainbow_glow_old");
			//CreateTempParticle("superrare_greenenergy", iEntity, _, _, true);
			//SDKHook(iEntity, SDKHook_SetTransmit, ShowToTarget);
			
			//Observer
			if (IsValidEntity(G_Observer)){
				G_Op_Rocket = iEntity;
				TeleportEntity(G_Observer, fPosition, fAngles, view_as<float>( { 0.0, 0.0, 0.0 } ));
				SetVariantString("!activator");
				AcceptEntityInput(G_Observer, "SetParent", G_Op_Rocket);
			}
		}
	}
}

/* PD.14:2 #DestroyRocket */
void DestroyRocket(int iIndex) {
	if (IsValidRocket(iIndex)) {
		int iEntity = EntRefToEntIndex(RINFO[iIndex].entity);
		if (iEntity && IsValidEntity(iEntity))RemoveEdict(iEntity);
		RINFO[iIndex].isValid = false;
		R_Count--;
	}
}

/* PD.14:3 #DestroyRockets */
void DestroyRockets() {
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++) 
		DestroyRocket(iIndex);
	R_Count = 0;
}

/* PD.14:4 #IsValidRocket */
bool IsValidRocket(int iIndex) {
	if ((iIndex >= 0) && (RINFO[iIndex].isValid == true)) {
		if (EntRefToEntIndex(RINFO[iIndex].entity) == -1) {
			RINFO[iIndex].isValid = false;
			R_Count--;
			return false;
		}
		return true;
	}
	return false;
}

/* PD.14:5 #FindNextValidRocket */
int FindNextValidRocket(int iIndex, bool bWrap = false) {
	for (int iCurrent = iIndex + 1; iCurrent < MAX_ROCKETS; iCurrent++)
	if (IsValidRocket(iCurrent))
		return iCurrent;
	return (bWrap == true) ? FindNextValidRocket(-1, false) : -1;
}

/* PD.14:6 #FindFreeRocketSlot */
int FindFreeRocketSlot() {
	int iIndex = R_LastCreated;
	int iCurrent = iIndex;
	
	do {
		if (!IsValidRocket(iCurrent))return iCurrent;
		if ((++iCurrent) == MAX_ROCKETS)iCurrent = 0;
	} while (iCurrent != iIndex);
	return -1;
}

/* PD.14:7 #FindRocketByEntity */
int FindRocketByEntity(int iEntity) {
	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1)
		if (EntRefToEntIndex(RINFO[iIndex].entity) == iEntity)
		return iIndex;
	
	return -1;
}

/* PD.14:8 #HomingRocketThink */
void HomingRocketThink(int iIndex) {
	// Retrieve the rocket's attributes.
	int iEntity = EntRefToEntIndex(RINFO[iIndex].entity);
	int iClass = RINFO[iIndex].class;
	RocketFlags iFlags = RINFO[iIndex].flags;
	int iTarget = EntRefToEntIndex(RINFO[iIndex].target);
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iDeflectionCount = GetEntProp(iEntity, Prop_Send, "m_iDeflected") - 1;
	float fModifier = CalculateModifier(iClass, iDeflectionCount);
	
	// Check if the target is available
	if (!IsValidClient(iTarget, true)) {
		iTarget = SelectTarget(iTargetTeam);
		if (!IsValidClient(iTarget, true))return;
		RINFO[iIndex].target = EntIndexToEntRef(iTarget);
		
		if (GetConVarBool(CVAR_RedirectBeep)) {
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		}
	}
	// Has the rocket been deflected recently? If so, set new target.
	else if ((iDeflectionCount > RINFO[iIndex].deflections)) {
		// Calculate new direction from the player's forward
		int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if (IsValidClient(iClient)) {
			float fViewAngles[3];
			float fDirection[3];
			GetClientEyeAngles(iClient, fViewAngles);
			GetAngleVectors(fViewAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
			CopyVectors(fDirection, RINFO[iIndex].direction);
			UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
			if (GetConVarBool(CVAR_StealPrevention))
			{
				checkStolenRocket(iClient, iIndex);
			}
		}
		
		// Set new target & deflection count
		iTarget = SelectTarget(iTargetTeam, iIndex);
		RINFO[iIndex].target = EntIndexToEntRef(iTarget);
		RINFO[iIndex].deflections = iDeflectionCount;
		RINFO[iIndex].lastDeflectionTime = GetGameTime();
		RINFO[iIndex].speed = CalculateRocketSpeed(iClass, fModifier);
		G_LastRocketSpeed = CalculateSpeed(RINFO[iIndex].speed);
		
		R_PreventingDelay = false;
		
		
		SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(iClass, fModifier), true);
		if (TestFlags(iFlags, RocketFlag_ElevateOnDeflect))
			RINFO[iIndex].flags |= RocketFlag_Elevating;
		EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		//Send out temp entity to target
		//SendTempEnt(iTarget, "superrare_greenenergy", iEntity, _, _, true);
		
		// Execute appropiate command
		if (TestFlags(iFlags, RocketFlag_OnDeflectCmd))
			ExecuteCommands(RCLASS[iClass].commandsOnDeflect, iClass, iEntity, iClient, iTarget, G_LastDeadClient, RINFO[iIndex].speed, iDeflectionCount);
		
	} else {
		// If the delay time since the last reflection has been elapsed, rotate towards the client.
		if ((GetGameTime() - RINFO[iIndex].lastDeflectionTime) >= RCLASS[iClass].controlDelay) {
			// Calculate turn rate and retrieve directions.
			float fTurnRate = CalculateRocketTurnRate(iClass, fModifier);
			float fDirectionToTarget[3]; CalculateDirectionToClient(iEntity, iTarget, fDirectionToTarget);
			
			// Elevate the rocket after a deflection (if it's enabled on the class definition, of course.)
			if (RINFO[iIndex].flags & RocketFlag_Elevating) {
				if (RINFO[iIndex].direction[2] < RCLASS[iClass].elevationLimit) {
					RINFO[iIndex].direction[2] = FMin(RINFO[iIndex].direction[2] + RCLASS[iClass].elevationRate, RCLASS[iClass].elevationLimit);
					fDirectionToTarget[2] = RINFO[iIndex].direction[2];
				} else {
					RINFO[iIndex].flags &= ~RocketFlag_Elevating;
				}
			}
			
			// Smoothly change the orientation to the new one.
			LerpVectors(RINFO[iIndex].direction, fDirectionToTarget, RINFO[iIndex].direction, fTurnRate);
		}
		
		// If it's a nuke, beep every some time
		if ((GetGameTime() - RINFO[iIndex].lastBeepTime) >= RCLASS[iClass].beepInterval) {
			RINFO[iIndex].isValid = true;
			EmitRocketSound(RocketSound_Beep, iClass, iEntity, iTarget, iFlags);
			RINFO[iIndex].lastBeepTime = GetGameTime();
		}
		
		if (GetConVarBool(CVAR_DelayPrevention)) {
			checkRoundDelays(iIndex);
		}
	}
	
	// Done
	ApplyRocketParameters(iIndex);
}

/* PD.14:9 #DestroyRocketClasses */
void DestroyRocketClasses() {
	for (int iIndex = 0; iIndex < RC_Count; iIndex++) {
		Handle hCmdOnSpawn = RCLASS[iIndex].commandsOnSpawn;
		Handle hCmdOnKill = RCLASS[iIndex].commandsOnKill;
		Handle hCmdOnExplode = RCLASS[iIndex].commandsOnExplode;
		Handle hCmdOnDeflect = RCLASS[iIndex].commandsOnDeflect;
		if (hCmdOnSpawn != INVALID_HANDLE)CloseHandle(hCmdOnSpawn);
		if (hCmdOnKill != INVALID_HANDLE)CloseHandle(hCmdOnKill);
		if (hCmdOnExplode != INVALID_HANDLE)CloseHandle(hCmdOnExplode);
		if (hCmdOnDeflect != INVALID_HANDLE)CloseHandle(hCmdOnDeflect);
		RCLASS[iIndex].commandsOnSpawn = INVALID_HANDLE;
		RCLASS[iIndex].commandsOnKill = INVALID_HANDLE;
		RCLASS[iIndex].commandsOnExplode = INVALID_HANDLE;
		RCLASS[iIndex].commandsOnDeflect = INVALID_HANDLE;
	}
	RC_Count = 0;
	ClearTrie(RC_Trie);
}



//
// PD.15 #CALCULATION
//
/* PD.15:1 #CalculateModifier */
float CalculateModifier(int iClass, int iDeflections) {
	return iDeflections + 
	(G_RocketsFired * RCLASS[iClass].rocketModifier) + 
	(G_PlayerCount * RCLASS[iClass].playerModifier);
}

/* PD.15:2 #CalculateRocketDamage */
float CalculateRocketDamage(int iClass, float fModifier) {
	return RCLASS[iClass].damage + RCLASS[iClass].damageIncrement * fModifier;
}

/* PD.15:3 #CalculateRocketSpeed */
float CalculateRocketSpeed(int iClass, float fModifier) {
	return RCLASS[iClass].speed + RCLASS[iClass].speedIncrement * fModifier;
}

/* PD.15:4 #CalculateRocketTurnRate */
float CalculateRocketTurnRate(int iClass, float fModifier) {
	return RCLASS[iClass].turnRate + RCLASS[iClass].turnRateIncrement * fModifier;
}

/* PD.15:5 #CalculateDirectionToClient */
void CalculateDirectionToClient(int iEntity, int iClient, float fOut[3]) {
	float fRocketPosition[3]; 
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
	GetClientEyePosition(iClient, fOut);
	MakeVectorFromPoints(fRocketPosition, fOut, fOut);
	NormalizeVector(fOut, fOut);
}

/* PD.15:6 #CalculateApplyRocketParameters */
void ApplyRocketParameters(int iIndex) {
	int iEntity = EntRefToEntIndex(RINFO[iIndex].entity);
	float fAngles[3]; GetVectorAngles(RINFO[iIndex].direction, fAngles);
	float fVelocity[3]; CopyVectors(RINFO[iIndex].direction, fVelocity);
	ScaleVector(fVelocity, RINFO[iIndex].speed);
	SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fVelocity);
	SetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngles);
}

/* PD.15:7 #UpdateRocketSkin */
void UpdateRocketSkin(int iEntity, int iTeam, bool bNeutral) {
	if (bNeutral == true)SetEntProp(iEntity, Prop_Send, "m_nSkin", 2);
	else SetEntProp(iEntity, Prop_Send, "m_nSkin", (iTeam == view_as<int>(TFTeam_Blue)) ? 0 : 1);
}

/* PD.15:8 #GetRandomRocketClass */
int GetRandomRocketClass(int iSpawnerClass) {
	int iRandom = GetURandomIntRange(0, 101);
	Handle hTable = SCLASS[iSpawnerClass].chancesTable;
	int iTableSize = GetArraySize(hTable);
	int iChancesLower = 0;
	int iChancesUpper = 0;
	for (int iEntry = 0; iEntry < iTableSize; iEntry++){
		iChancesLower += iChancesUpper;
		iChancesUpper = iChancesLower + GetArrayCell(hTable, iEntry);
		if ((iRandom >= iChancesLower) && (iRandom < iChancesUpper)){
			return iEntry;
		}
	}
	
	return 0;
}




void EmitRocketSound(RocketSound iSound, int iClass, int iEntity, int iTarget, RocketFlags iFlags) {
	switch (iSound) {
		case RocketSound_Spawn: {
			if (TestFlags(iFlags, RocketFlag_PlaySpawnSound)) {
				if (TestFlags(iFlags, RocketFlag_CustomSpawnSound))EmitSoundToAll(RCLASS[iClass].spawnSound, iEntity);
				else EmitSoundToAll(SOUND_DEFAULT_SPAWN, iEntity);
			}
		} case RocketSound_Beep: {
			if (TestFlags(iFlags, RocketFlag_PlayBeepSound)) {
				if (TestFlags(iFlags, RocketFlag_CustomBeepSound))EmitSoundToAll(RCLASS[iClass].beepSound, iEntity);
				else EmitSoundToAll(SOUND_DEFAULT_BEEP, iEntity);
			}
		} case RocketSound_Alert: {
			if (TestFlags(iFlags, RocketFlag_PlayAlertSound)) {
				if (TestFlags(iFlags, RocketFlag_CustomAlertSound))EmitSoundToClient(iTarget, RCLASS[iClass].alertSound);
				else EmitSoundToClient(iTarget, SOUND_DEFAULT_ALERT, _, _, _, _, 0.5);
			}
		}
	}
}



void DestroySpawners() {
	for (int iIndex = 0; iIndex < SC_Count; iIndex++) {
		CloseHandle(SCLASS[iIndex].chancesTable);
	}
	SC_Count = 0;
	SC_SpawnPointsRedCount = 0;
	SC_SpawnPointsBluCount = 0;
	SC_DefaultRedSpawner = -1;
	SC_DefaultBluSpawner = -1;
	RC_SavedClassName[0] = '\0';
	ClearTrie(SC_Trie);
}

void PopulateSpawnPoints() {
	// Clear the current settings
	SC_SpawnPointsRedCount = 0;
	SC_SpawnPointsBluCount = 0;
	
	// Iterate through all the info target points and check 'em out.
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "info_target")) != -1) {
		char strName[32]; GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
		if ((StrContains(strName, "rocket_spawn_red") != -1) || (StrContains(strName, "tf_dodgeball_red") != -1)) {
			// Find most appropiate spawner class for this entity.
			int iIndex = FindSpawnerByName(strName);
			if (!IsValidRocket(iIndex))iIndex = SC_DefaultRedSpawner;
			
			// Upload to point list
			SPCLASS[SC_SpawnPointsRedCount].spawnPointsRedClass = iIndex;
			SPCLASS[SC_SpawnPointsRedCount].spawnPointsRedEntity = iEntity;
			SC_SpawnPointsRedCount++;
		}
		if ((StrContains(strName, "rocket_spawn_blue") != -1) || (StrContains(strName, "tf_dodgeball_blu") != -1)) {
			// Find most appropiate spawner class for this entity.
			int iIndex = FindSpawnerByName(strName);
			if (!IsValidRocket(iIndex))iIndex = SC_DefaultBluSpawner;
			
			// Upload to point list
			SPCLASS[SC_SpawnPointsBluCount].spawnPointsBluClass = iIndex;
			SPCLASS[SC_SpawnPointsBluCount].spawnPointsBluEntity = iEntity;
			SC_SpawnPointsBluCount++;
		}
	}
	
	// Check if there exists spawn points
	if (SC_SpawnPointsRedCount == 0)
		SetFailState("No RED spawn points found on this map.");
	
	if (SC_SpawnPointsBluCount == 0)
		SetFailState("No BLU spawn points found on this map.");
	
	
	//ObserverPoint
	float opPos[3];
	float opAng[3];
	
	int spawner = GetRandomInt(0, 1);
	if (spawner == 0)
		spawner = SPCLASS[0].spawnPointsRedEntity;
	else
		spawner = SPCLASS[0].spawnPointsBluEntity;
	
	if (IsValidEntity(spawner) && spawner > MAXPLAYERS) {
		GetEntPropVector(spawner, Prop_Data, "m_vecOrigin", opPos);
		GetEntPropVector(spawner, Prop_Data, "m_angAbsRotation", opAng);
		G_Observer = CreateEntityByName("info_observer_point");
		DispatchKeyValue(G_Observer, "Angles", "90 0 0");
		DispatchKeyValue(G_Observer, "TeamNum", "0");
		DispatchKeyValue(G_Observer, "StartDisabled", "0");
		DispatchSpawn(G_Observer);
		AcceptEntityInput(G_Observer, "Enable");
		TeleportEntity(G_Observer, opPos, opAng, NULL_VECTOR);
	} else {
		G_Observer = -1;
	}
	
}

int FindSpawnerByName(char strName[32]) {
	int iIndex = -1;
	GetTrieValue(SC_Trie, strName, iIndex);
	return iIndex;
}

void ExecuteCommands(Handle hDataPack, int iClass, int iRocket, int iOwner, int iTarget, int iLastDead, float fSpeed, int iNumDeflections) {
	ResetPack(hDataPack, false);
	int iNumCommands = ReadPackCell(hDataPack);
	while (iNumCommands-- > 0) {
		char strCmd[256];
		char strBuffer[8];
		ReadPackString(hDataPack, strCmd, sizeof(strCmd));
		ReplaceString(strCmd, sizeof(strCmd), "@name", RCLASS[iClass].longName);
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
bool ParseConfigurations(char[] strConfigFile) {
	// Parse configuration
	char strPath[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	Format(strFileName, sizeof(strFileName), "configs/dodgeball/%s", strConfigFile);
	BuildPath(Path_SM, strPath, sizeof(strPath), strFileName);
	
	// Try to parse if it exists
	LogMessage("Executing configuration file %s", strPath);
	if (FileExists(strPath, true)) {
		KeyValues kvConfig = CreateKeyValues("TF2_Dodgeball");
		
		if (FileToKeyValues(kvConfig, strPath) == false)
			SetFailState("Error while parsing the configuration file.");
		
		kvConfig.GotoFirstSubKey();
		
		// Parse the subsections
		do {
			char strSection[64];
			KvGetSectionName(kvConfig, strSection, sizeof(strSection));
			
			
			if (StrEqual(strSection, "classes"))
				ParseClasses(kvConfig);
			else if (StrEqual(strSection, "spawners"))
				ParseSpawners(kvConfig);
		} while (KvGotoNextKey(kvConfig));
		
		CloseHandle(kvConfig);
	}
}


void ParseClasses(Handle kvConfig) {
	char strName[64];
	char strBuffer[256];
	
	KvGotoFirstSubKey(kvConfig);
	do {
		int iIndex = RC_Count;
		RocketFlags iFlags;
		
		// Basic parameters
		KvGetSectionName(kvConfig, strName, sizeof(strName)); 
		strcopy(RCLASS[iIndex].name, 16, strName);

		KvGetString(kvConfig, "name", strBuffer, sizeof(strBuffer)); 
		strcopy(RCLASS[iIndex].longName, 32, strBuffer);

		if (KvGetString(kvConfig, "model", strBuffer, sizeof(strBuffer))) {
			strcopy(RCLASS[iIndex].model, PLATFORM_MAX_PATH, strBuffer);
			if (strlen(RCLASS[iIndex].model) != 0) {
				iFlags |= RocketFlag_CustomModel;
				if (KvGetNum(kvConfig, "is animated", 0))iFlags |= RocketFlag_IsAnimated;
			}
		}
		if (KvGetNum(kvConfig, "play spawn sound", 0) == 1) {
			iFlags |= RocketFlag_PlaySpawnSound;
			if (KvGetString(kvConfig, "spawn sound", RCLASS[iIndex].spawnSound, PLATFORM_MAX_PATH) && (strlen(RCLASS[iIndex].spawnSound) != 0)) {
				iFlags |= RocketFlag_CustomSpawnSound;
			}
		}
		if (KvGetNum(kvConfig, "play beep sound", 0) == 1) {
			iFlags |= RocketFlag_PlayBeepSound;
			RCLASS[iIndex].beepInterval = KvGetFloat(kvConfig, "beep interval", 0.5);
			if (KvGetString(kvConfig, "beep sound", RCLASS[iIndex].beepSound, PLATFORM_MAX_PATH) && (strlen(RCLASS[iIndex].beepSound) != 0)) {
				iFlags |= RocketFlag_CustomBeepSound;
			}
		}
		if (KvGetNum(kvConfig, "play alert sound", 0) == 1) {
			iFlags |= RocketFlag_PlayAlertSound;
			if (KvGetString(kvConfig, "alert sound", RCLASS[iIndex].alertSound, PLATFORM_MAX_PATH) && strlen(RCLASS[iIndex].alertSound) != 0) {
				iFlags |= RocketFlag_CustomAlertSound;
			}
		}
		// Behaviour modifiers
		if (KvGetNum(kvConfig, "elevate on deflect", 1) == 1)iFlags |= RocketFlag_ElevateOnDeflect;
		if (KvGetNum(kvConfig, "neutral rocket", 0) == 1)iFlags |= RocketFlag_IsNeutral;
		
		// Movement parameters
		RCLASS[iIndex].damage = KvGetFloat(kvConfig, "damage");
		RCLASS[iIndex].damageIncrement = KvGetFloat(kvConfig, "damage increment");
		RCLASS[iIndex].critChance = KvGetFloat(kvConfig, "critical chance");
		RCLASS[iIndex].speed = KvGetFloat(kvConfig, "speed");
		R_SavedSpeed = RCLASS[iIndex].speed;
		RCLASS[iIndex].speedIncrement = KvGetFloat(kvConfig, "speed increment");
		R_SavedSpeedIncrement = RCLASS[iIndex].speedIncrement;
		RCLASS[iIndex].turnRate = KvGetFloat(kvConfig, "turn rate");
		RCLASS[iIndex].turnRateIncrement = KvGetFloat(kvConfig, "turn rate increment");
		RCLASS[iIndex].elevationRate = KvGetFloat(kvConfig, "elevation rate");
		RCLASS[iIndex].elevationLimit = KvGetFloat(kvConfig, "elevation limit");
		RCLASS[iIndex].controlDelay = KvGetFloat(kvConfig, "control delay");
		RCLASS[iIndex].playerModifier = KvGetFloat(kvConfig, "no. players modifier");
		RCLASS[iIndex].rocketModifier = KvGetFloat(kvConfig, "no. rockets modifier");
		RCLASS[iIndex].targetWeight = KvGetFloat(kvConfig, "direction to target weight");
		
		// Events
		Handle hCmds = INVALID_HANDLE;
		KvGetString(kvConfig, "on spawn", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnSpawnCmd; RCLASS[iIndex].commandsOnSpawn = hCmds; }
		KvGetString(kvConfig, "on deflect", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnDeflectCmd; RCLASS[iIndex].commandsOnDeflect = hCmds; }
		KvGetString(kvConfig, "on kill", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnKillCmd; RCLASS[iIndex].commandsOnKill = hCmds; }
		KvGetString(kvConfig, "on explode", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != INVALID_HANDLE) { iFlags |= RocketFlag_OnExplodeCmd; RCLASS[iIndex].commandsOnExplode = hCmds; }
		
		// Done
		SetTrieValue(RC_Trie, strName, iIndex);
		RCLASS[iIndex].flags = iFlags;
		RC_Count++;
	}
	while (KvGotoNextKey(kvConfig));
	KvGoBack(kvConfig);
}

void ParseSpawners(KeyValues kvConfig) {
	kvConfig.JumpToKey("spawners"); //jump to spawners section
	char strBuffer[256];
	kvConfig.GotoFirstSubKey(); //goto to first subkey of "spawners" section
	
	do {
		int iIndex = SC_Count;
		
		// Basic parameters
		kvConfig.GetSectionName(strBuffer, sizeof(strBuffer)); //okay, here we got section name, as example, red
		strcopy(SCLASS[iIndex].name, 32, strBuffer); //here we copied it to the g_strSpawnersName array
		SCLASS[iIndex].maxRockets = kvConfig.GetNum("max rockets", 1); //get some values...
		SCLASS[iIndex].interval = kvConfig.GetFloat("interval", 1.0);
		
		// Chances table
		SCLASS[iIndex].chancesTable = CreateArray(); //not interested in this
		for (int iClassIndex = 0; iClassIndex < RC_Count; iClassIndex++) {
			Format(strBuffer, sizeof(strBuffer), "%s%%", RCLASS[iClassIndex].name);
			PushArrayCell(SCLASS[iIndex].chancesTable, KvGetNum(kvConfig, strBuffer, 0));
			if (KvGetNum(kvConfig, strBuffer, 0) == 100)
				strcopy(RC_SavedClassName, sizeof(RC_SavedClassName), RCLASS[iClassIndex].longName);
		}
		
		// Done.
		SetTrieValue(SC_Trie, SCLASS[iIndex].name, iIndex); //okay, push section name to g_hSpawnersTrie
		SC_Count++;
	} while (kvConfig.GotoNextKey());
	
	kvConfig.Rewind(); //rewind
	
	GetTrieValue(SC_Trie, "Red", SC_DefaultRedSpawner); //get value by section name, section name exists in the g_hSpawnersTrie, everything should work
	GetTrieValue(SC_Trie, "Blue", SC_DefaultBluSpawner);
}

Handle ParseCommands(char[] strLine) {
	TrimString(strLine);
	if (strlen(strLine) == 0) {
		return INVALID_HANDLE;
	} else {
		char strStrings[8][255];
		int iNumStrings = ExplodeString(strLine, ";", strStrings, 8, 255);
		
		Handle hDataPack = CreateDataPack();
		WritePackCell(hDataPack, iNumStrings);
		for (int i = 0; i < iNumStrings; i++) {
			WritePackString(hDataPack, strStrings[i]);
		}
		
		return hDataPack;
	}
}

public Action ApplyDamage(Handle hTimer, any hDataPack) {
	ResetPack(hDataPack, false);
	int iClient = ReadPackCell(hDataPack);
	int iDamage = ReadPackCell(hDataPack);
	CloseHandle(hDataPack);
	SlapPlayer(iClient, iDamage, true);
}

stock void CopyVectors(float fFrom[3], float fTo[3]) {
	fTo[0] = fFrom[0];
	fTo[1] = fFrom[1];
	fTo[2] = fFrom[2];
}

stock void LerpVectors(float fA[3], float fB[3], float fC[3], float t) {
	if (t < 0.0)t = 0.0;
	if (t > 1.0)t = 1.0;
	
	fC[0] = fA[0] + (fB[0] - fA[0]) * t;
	fC[1] = fA[1] + (fB[1] - fA[1]) * t;
	fC[2] = fA[2] + (fB[2] - fA[2]) * t;
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

stock bool BothTeamsPlaying() {
	bool bRedFound;
	bool bBluFound;
	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (IsValidClient(iClient, true) == false)continue;
		int iTeam = GetClientTeam(iClient);
		if (iTeam == view_as<int>(TFTeam_Red))bRedFound = true;
		if (iTeam == view_as<int>(TFTeam_Blue))bBluFound = true;
	}
	return bRedFound && bBluFound;
}

int CountPlayers(bool bAlive) {
	int iCount = 0;
	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		if (IsValidClient(iClient, bAlive))
			iCount++;
	}
	return iCount;
}

stock int SelectTarget(int iTeam, int iRocket = -1) {
	int iTarget = -1;
	float fTargetWeight = 0.0;
	float fRocketPosition[3];
	float fRocketDirection[3];
	float fWeight;
	bool bUseRocket;
	
	if (iRocket != -1) {
		int iClass = RINFO[iRocket].class;
		int iEntity = EntRefToEntIndex(RINFO[iRocket].entity);
		
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
		CopyVectors(RINFO[iRocket].direction, fRocketDirection);
		fWeight = RCLASS[iClass].targetWeight;
		
		bUseRocket = true;
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++) {
		// If the client isn't connected, skip.
		if (!IsValidClient(iClient, true))continue;
		if (iTeam && GetClientTeam(iClient) != iTeam)continue;
		
		// Determine if this client should be the target.
		float fNewWeight = GetURandomFloatRange(0.0, 100.0);
		
		if (bUseRocket == true) {
			float fClientPosition[3]; GetClientEyePosition(iClient, fClientPosition);
			float fDirectionToClient[3]; MakeVectorFromPoints(fRocketPosition, fClientPosition, fDirectionToClient);
			fNewWeight += GetVectorDotProduct(fRocketDirection, fDirectionToClient) * fWeight;
		}
		
		if ((iTarget == -1) || fNewWeight >= fTargetWeight) {
			iTarget = iClient;
			fTargetWeight = fNewWeight;
		}
	}
	
	return iTarget;
}

stock void PlayParticle(float fPosition[3], float fAngles[3], char[] strParticleName, float fEffectTime = 5.0, float fLifeTime = 9.0) {
	int iEntity = CreateEntityByName("info_particle_system");
	if (iEntity && IsValidEdict(iEntity)) {
		TeleportEntity(iEntity, fPosition, fAngles, NULL_VECTOR);
		DispatchKeyValue(iEntity, "effect_name", strParticleName);
		ActivateEntity(iEntity);
		AcceptEntityInput(iEntity, "Start");
		CreateTimer(fEffectTime, StopParticle, EntIndexToEntRef(iEntity));
		CreateTimer(fLifeTime, KillParticle, EntIndexToEntRef(iEntity));
	} else {
		LogError("ShowParticle: could not create info_particle_system");
	}
}

public Action StopParticle(Handle hTimer, any iEntityRef) {
	if (iEntityRef != INVALID_ENT_REFERENCE) {
		int iEntity = EntRefToEntIndex(iEntityRef);
		if (iEntity && IsValidEntity(iEntity)) {
			AcceptEntityInput(iEntity, "Stop");
		}
	}
}

public Action KillParticle(Handle hTimer, any iEntityRef) {
	if (iEntityRef != INVALID_ENT_REFERENCE) {
		int iEntity = EntRefToEntIndex(iEntityRef);
		if (iEntity && IsValidEntity(iEntity)) {
			RemoveEdict(iEntity);
		}
	}
}

stock void PrecacheParticle(char[] strParticleName) {
	PlayParticle(view_as<float>( { 0.0, 0.0, 0.0 } ), view_as<float>( { 0.0, 0.0, 0.0 } ), strParticleName, 0.1, 0.1);
}
/*
stock void FindEntityByClassnameSafe(int iStart, const char[] strClassname) {
	while (iStart > -1 && !IsValidEntity(iStart)) {
		iStart--;
	}
	return FindEntityByClassname(iStart, strClassname);
}
*/

stock int GetAnalogueTeam(int iTeam) {
	if (iTeam == view_as<int>(TFTeam_Red))return view_as<int>(TFTeam_Blue);
	return view_as<int>(TFTeam_Red);
}

stock void ShowHiddenMOTDPanel(int iClient, char[] strTitle, char[] strMsg, char[] strType = "2") {
	Handle hPanel = CreateKeyValues("data");
	KvSetString(hPanel, "title", strTitle);
	KvSetString(hPanel, "type", strType);
	KvSetString(hPanel, "msg", strMsg);
	ShowVGUIPanel(iClient, "info", hPanel, false);
	CloseHandle(hPanel);
}

stock void PrecacheSoundEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false) {
	char strFinalPath[PLATFORM_MAX_PATH];
	Format(strFinalPath, sizeof(strFinalPath), "sound/%s", strFileName);
	PrecacheSound(strFileName, bPreload);
	if (bAddToDownloadTable == true)AddFileToDownloadsTable(strFinalPath);
}

stock void PrecacheModelEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false) {
	PrecacheModel(strFileName, bPreload);
	if (bAddToDownloadTable) {
		char strDepFileName[PLATFORM_MAX_PATH];
		Format(strDepFileName, sizeof(strDepFileName), "%s.res", strFileName);
		
		if (FileExists(strDepFileName)) {
			// Open stream, if possible
			Handle hStream = OpenFile(strDepFileName, "r");
			if (hStream == INVALID_HANDLE) { LogMessage("Error, can't read file containing model dependencies."); return; }
			
			while (!IsEndOfFile(hStream)) {
				char strBuffer[PLATFORM_MAX_PATH];
				ReadFileLine(hStream, strBuffer, sizeof(strBuffer));
				CleanString(strBuffer);
				
				// If file exists...
				if (FileExists(strBuffer, true)) {
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

stock void CleanString(char[] strBuffer) {
	// Cleanup any illegal characters
	int Length = strlen(strBuffer);
	for (int iPos = 0; iPos < Length; iPos++) {
		switch (strBuffer[iPos]) {
			case '\r':strBuffer[iPos] = ' ';
			case '\n':strBuffer[iPos] = ' ';
			case '\t':strBuffer[iPos] = ' ';
		}
	}
	
	// Trim string
	TrimString(strBuffer);
}

stock float FMax(float a, float b){
	return (a > b) ? a:b;
}

stock float FMin(float a, float b){
	return (a < b) ? a:b;
}

stock int GetURandomIntRange(const int iMin, const int iMax){
	return iMin + (GetURandomInt() % (iMax - iMin + 1));
}

stock float GetURandomFloatRange(float fMin, float fMax){
	return fMin + (GetURandomFloat() * (fMax - fMin));
}

// Pyro vision
public void tf2dodgeball_hooks(Handle convar, const char[] oldValue, const char[] newValue) {
	if (GetConVarBool(CVAR_AutoPyroVision)) {
		for (int i = 1; i <= MaxClients; ++i) {
			if (IsClientInGame(i))
			{
				TF2Attrib_SetByName(i, PYROVISION_ATTRIBUTE, 1.0);
			}
		}
	} else {
		for (int i = 1; i <= MaxClients; ++i) {
			if (IsClientInGame(i)) {
				TF2Attrib_RemoveByName(i, PYROVISION_ATTRIBUTE);
			}
		}
	}
	
	if (convar == CVAR_MaxRocketBounces)
		G_MaxRocketBounces = StringToInt(newValue);
}

// 
// PD.16 Asherkins Rocketbounce
//

public void OnEntityCreated(int entity, const char[] classname) {
	if (G_MapIsTFDB && StrEqual(classname, "tf_projectile_rocket", true)) {
		if (StrEqual(classname, "tf_projectile_rocket") || StrEqual(classname, "tf_projectile_sentryrocket")) {
			if (IsValidEntity(entity)) {
				SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", entity);
				SetEntPropEnt(entity, Prop_Send, "m_hLauncher", entity);
			}
		}
		G_Bounces[entity] = 0;
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
	}
}
public Action OnStartTouch(int entity, int other) {
	if (other > 0 && other <= MaxClients)
		return Plugin_Continue;
	if (G_Bounces[entity] >= G_MaxRocketBounces)
		return Plugin_Continue;
	SDKHook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}
public Action OnTouch(int entity, int other) {
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
	G_Bounces[entity]++;
	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}
public bool TEF_ExcludeEntity(int entity, int contentsMask, any data) {
	return (entity != data);
}


// 
// PD.17 AirBlast Prevention
//
void preventAirblast(int clientId, bool prevent) {
	int flags;
	if (prevent == true) {
		flags = GetEntityFlags(clientId) | FL_NOTARGET;
	} else {
		flags = GetEntityFlags(clientId) & ~FL_NOTARGET;
	}
	SetEntityFlags(clientId, flags);
}

public Action TauntCheck(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (!G_MapIsTFDB)
		return Plugin_Continue;
	
	switch (damagecustom) {
		case TF_CUSTOM_TAUNT_ARMAGEDDON: {
			damage = 0.0;
			return Plugin_Changed;
		}
		
	}
	return Plugin_Continue;
}

void checkStolenRocket(int iClient, int entId) {
	if (EntRefToEntIndex(RINFO[entId].target) != iClient && !StealPlayer[iClient].stoleRocket && (GetClientTeam(iClient) != GetClientTeam(RINFO[entId].target))) {
		StealPlayer[iClient].stoleRocket = true;
		if (StealPlayer[iClient].rocketsStolen < GetConVarInt(CVAR_StealPreventionCount)) {
			StealPlayer[iClient].rocketsStolen++;
			CreateTimer(0.1, tStealTimer, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
			SlapPlayer(iClient, 0, true);
			CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}Do not steal rockets. [Warning {dodgerblue}%i{default}/{dodgerblue}%i{default}]", StealPlayer[iClient].rocketsStolen, GetConVarInt(CVAR_StealPreventionCount));
		} else {
			ForcePlayerSuicide(iClient);
			//DeleteRocket(entId);
			CPrintToChat(iClient, "{mediumpurple}ᴅʙ {black}» {default}You have been slain for stealing rockets.");
			CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {dodgerblue}%N {default}was slain for stealing rockets.", iClient);
		}
	}
}

public void checkRoundDelays(int entId) {
	int iEntity = EntRefToEntIndex(RINFO[entId].entity);
	int iTarget = EntRefToEntIndex(RINFO[entId].target);
	float timeToCheck;
	if (RINFO[entId].deflections == 0)
		timeToCheck = G_LastSpawnTime;
	else
		timeToCheck = RINFO[entId].lastDeflectionTime;
	
	if (iTarget != INVALID_ENT_REFERENCE && (GetGameTime() - timeToCheck) >= GetConVarFloat(CVAR_DelayPreventionTime)) {
		RINFO[entId].speed += GetConVarFloat(CVAR_DelayPreventionSpeedup);
		if (!R_PreventingDelay) {
			CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {dodgerblue}%N {default}is delaying, the rocket will now speed up.", iTarget);
			EmitSoundToAll(SOUND_DEFAULT_SPEEDUPALERT, iEntity, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
		}
		R_PreventingDelay = true;
	}
}


public void SetMainRocketClass(int iIndex, int client = 0) {
	int iSpawnerClassRed = SPCLASS[SC_CurrentRedSpawn].spawnPointsRedClass;
	char strBufferRed[256];
	strcopy(strBufferRed, sizeof(strBufferRed), "Red");
	
	Format(strBufferRed, sizeof(strBufferRed), "%s%%", RCLASS[iIndex].name);
	SetArrayCell(SCLASS[iSpawnerClassRed].chancesTable, iIndex, 100);
	
	for (int iClassIndex = 0; iClassIndex < RC_Count; iClassIndex++) {
		if (!(iClassIndex == iIndex)) {
			Format(strBufferRed, sizeof(strBufferRed), "%s%%", RCLASS[iClassIndex].name);
			SetArrayCell(SCLASS[iSpawnerClassRed].chancesTable, iClassIndex, 0);
		}
	}
	int iSpawnerClassBlu = SPCLASS[SC_CurrentBluSpawn].spawnPointsBluClass;
	char strBufferBlue[256];
	strcopy(strBufferBlue, sizeof(strBufferBlue), "Blue");
	Format(strBufferBlue, sizeof(strBufferBlue), "%s%%", RCLASS[iIndex].name);
	SetArrayCell(SCLASS[iSpawnerClassBlu].chancesTable, iIndex, 100);
	char strSelectionBlue[256];
	strcopy(strSelectionBlue, sizeof(strBufferBlue), strBufferBlue);
	for (int iClassIndex = 0; iClassIndex < RC_Count; iClassIndex++) {
		if (!(iClassIndex == iIndex)) {
			Format(strBufferBlue, sizeof(strBufferBlue), "%s%%", RCLASS[iClassIndex].name);
			SetArrayCell(SCLASS[iSpawnerClassBlu].chancesTable, iClassIndex, 0);
		}
	}
	int iClass = GetRandomRocketClass(iSpawnerClassRed);
	strcopy(RC_SavedClassName, sizeof(RC_SavedClassName), RCLASS[iClass].longName);
	CPrintToChatAll("{mediumpurple}ᴅʙ {black}» {deodgerblue}%N{default} changed the rocket class to {dodgerblue}%s{default}.", client, RCLASS[iClass].longName);
}

float CalculateSpeed(float speed){
	return speed * (15.0 / 350.0);
}

public Action tStealTimer(Handle hTimer, int iClientUid){
	int iClient = GetClientOfUserId(iClientUid);
	StealPlayer[iClient].stoleRocket = false;
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

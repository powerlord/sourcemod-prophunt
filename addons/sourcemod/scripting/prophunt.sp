/**
 * vim: set ts=4 :
 * =============================================================================
 * TF2 PropHunt Redux
 * Hide as a prop from the evil Pyro menace... or hunt down the hidden prop scum
 * 
 * TF2 PropHunt (C)2007-2014 Darkimmortal.  All rights reserved.
 * TF2 PropHunt Redux (C)2013-2014 Powerlord (Ross Bemrose).  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: 4.0.0
 */
// PropHunt Redux by Powerlord
//         Based on
//  PropHunt by Darkimmortal
//   - GamingMasters.org -

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include "morecolors.inc"

#undef REQUIRE_EXTENSIONS
#include <steamtools>
#include <SteamWorks>

#undef REQUIRE_PLUGIN
#include <updater>

#define REQUIRE_EXTENSIONS
#define REQUIRE_PLUGIN
#pragma semicolon 1
#pragma newdecls required

#if !defined SNDCHAN_VOICE2
#define SNDCHAN_VOICE2 7
#endif

// This should be defined by SourceMod, but isn't.
#define ADMFLAG_NONE 0

#define MAXLANGUAGECODE 4

#define PL_VERSION "4.0.0.0 alpha 1"

// sv_tags has a 255 limit
#define SV_TAGS_SIZE 255 

//--------------------------------------------------------------------------------------------------------------------------------
//-------------------------------------------- MAIN PROPHUNT CONFIGURATION -------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------------

// Enable for global stats support (.inc file available on request due to potential for cheating and database abuse)
// Default: OFF
//#define STATS

// GM only stuff
//#define GM
 
#if defined GM
#define SELECTOR_PORTS "27019,27301"
#include <selector>
#endif

// Include support for Workshop maps
// Requires SourceMod 1.8 or later
// Default: ON
#define WORKSHOP_SUPPORT

// Include support for Opt-In MultiMod
// Default: OFF
//#define OIMM

// Include support for switching teams using gamedata
// You only really want to disable this if team switchs aren't working (i.e. gamedata hasn't yet been updated)
// Default: ON
#define SWITCH_TEAMS

// Give last prop a scattergun and apply jarate to all pyros on last prop alive
// Default: ON
#define SCATTERGUN

// Prop Lock/Unlock sounds
// Default: ON
#define LOCKSOUND

// Extra classes
// Default: ON
#define SHINX

// Event and query logging for debugging purposes
// Default: OFF
//#define LOG

// Allow props to Targe Charge with enemy collisions disabled by pressing reload - pretty shit tbh.
// Default: OFF
//#define CHARGE

// Max ammo in Pyro shotgun
// Default: 2
#define SHOTGUN_MAX_AMMO 2

// Deprecated and switched to ph_antihack cvar
// Anti-exploit system
// Default: ON
//#define ANTIHACK

// How long after a prop damages a Pyro should the they be credited for damaging them?
// Only applies during Last Prop mode and if a pyro kills themselves
// Default: 5
#define PROP_DAMAGE_TIME 5

// How many seconds before the round changes should teams be switched?
// Lowest possible setting is 0.1 due to how SourceMod timers work internally.
// Setting this lower than 0.2 may cause issues with some servers for the same issue as above.
// Default: 0.2
#define TEAM_CHANGE_TIME 0.2

// Minimum and maximum setup times
#define SETUP_MIN 30
#define SETUP_MAX 120

// "Production" URL (3.3 branch)
//#define UPDATE_URL "http://tf2.rbemrose.com/sourcemod/prophunt/prophunt.txt"

// "Dev" URL (3.4 branch)
#define UPDATE_URL "http://tf2.rbemrose.com/sourcemod/prophunt/dev/prophunt.txt"

//--------------------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------------------------------------

#if defined OIMM
#include <optin_multimod>
#endif 

// Needed for stats2.inc compatibility
#define TEAM_BLUE view_as<int>(TFTeam_Blue)
#define TEAM_RED view_as<int>(TFTeam_Red)
#define TEAM_SPEC view_as<int>(TFTeam_Spectator)
#define TEAM_UNASSIGNED view_as<int>(TFTeam_Unassigned)

#define TEAM_PROP TEAM_RED
#define TEAM_HUNTER TEAM_BLUE

#define FLAMETHROWER "models/weapons/w_models/w_flamethrower.mdl"

#define STATE_WAT -1
#define STATE_IDLE 0
#define STATE_RUNNING 1
#define STATE_SWING 2
#define STATE_CROUCH 3

// Not sure what this is for, but pretty sure it's wrong.. player conditions are no longer defined like this
#define PLAYER_ONFIRE (1 << 14)

// Weapon Indexes
#define WEP_SHOTGUN_UNIQUE 199

//Pyro
#define WEP_SHOTGUNPYRO 12

#define WEP_PHLOGISTINATOR 594

#define LOCKVOL 0.7
#define UNBALANCE_LIMIT 1
#define MAXMODELNAME 96
// Not sure what this is for, but pretty sure it's wrong.. player conditions are no longer defined like this
#define TF2_PLAYERCOND_ONFIREALERT    (1<<20)

#define IN_MOVEMENT IN_MOVELEFT | IN_MOVERIGHT | IN_FORWARD | IN_BACK | IN_JUMP

#define TIMER_NAME "prop_hunt_timer"

enum
{
	Item_Classname,
	Item_Index,
	Item_Quality,
	Item_Level,
	Item_Attributes,
}

enum ScReason
{
	ScReason_TeamWin = 0,
	ScReason_TeamLose,
	ScReason_Death,
	ScReason_Kill,
	ScReason_Time,
	ScReason_Friendly
};

enum PropData
{
	String:PropData_Name[MAXMODELNAME],
	String:PropData_Offset[32], // 3 digits, plus 2 spaces, plus a null terminator
	String:PropData_Rotation[32], // 3 digits, plus 2 spaces, plus a null terminator
}

enum RoundChange
{
	RoundChange_NoChange,
	RoundChange_Enable,
	RoundChange_Disable,
}

enum
{
	ScoreData_Captures,
	ScoreData_Defenses,
	ScoreData_Kills,
	ScoreData_Deaths,
	ScoreData_Suicides,
	ScoreData_Dominations,
	ScoreData_Revenge,
	ScoreData_BuildingsBuilt,
	ScoreData_BuildingsDestroyed,
	ScoreData_Headshots,
	ScoreData_Backstabs,
	ScoreData_HealPoints,
	ScoreData_Invulns,
	ScoreData_Teleports,
	ScoreData_DamageDone,
	ScoreData_Crits,
	ScoreData_ResupplyPoints,
	ScoreData_KillAssists,
	ScoreData_BonusPoints,
	ScoreData_Points
}

enum
{
	TFClassBits_None = 0,
	TFClassBits_Scout = (1 << 0), // 1
	TFClassBits_Sniper = (1 << 1), // 2
	TFClassBits_Soldier = (1 << 2), // 4
	TFClassBits_DemoMan = (1 << 3), // 8
	TFClassBits_Medic = (1 << 4), // 16
	TFClassBits_Heavy = (1 << 5), // 32
	TFClassBits_Pyro = (1 << 6), // 64
	TFClassBits_Spy = (1 << 7), // 128
	TFClassBits_Engineer = (1 << 8) // 256
}

bool g_RoundOver = true;
bool g_inSetup = false;
bool g_inPreRound = true;
bool g_PlayerDied = false;
float g_flRoundStart = 0.0;

bool g_LastProp;
bool g_Attacking[MAXPLAYERS+1];
bool g_SetClass[MAXPLAYERS+1];
bool g_Spawned[MAXPLAYERS+1];
bool g_TouchingCP[MAXPLAYERS+1];
bool g_Charge[MAXPLAYERS+1];
bool g_First[MAXPLAYERS+1];
bool g_HoldingLMB[MAXPLAYERS+1];
bool g_HoldingRMB[MAXPLAYERS+1];
bool g_AllowedSpawn[MAXPLAYERS+1];
bool g_RotLocked[MAXPLAYERS+1];
bool g_Hit[MAXPLAYERS+1];
bool g_Spec[MAXPLAYERS+1];
char g_PlayerModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

char g_Mapname[PLATFORM_MAX_PATH];
char g_ServerIP[32];
char g_Version[16];

int g_Message_red;
int g_Message_blue;
int g_RoundTime = 175;
int g_Message_bit = 0;
int g_Setup = 0;

#if defined STATS
bool g_MapChanging = false;
int g_StartTime;
#endif

//new Handle:g_TimerStart = INVALID_HANDLE;
StringMap g_Sounds;
StringMap g_BroadcastSounds;

bool g_Doors = false;
bool g_Relay = false;
bool g_Freeze = true;

ArrayList g_hWeaponRemovals;
ArrayList g_hPropWeaponRemovals;
StringMap g_hWeaponNerfs;
StringMap g_hWeaponSelfDamage;
ArrayList g_hWeaponStripAttribs;
StringMap g_hWeaponAddAttribs;
StringMap g_hWeaponReplacements;
StringMap g_hWeaponReplacementPlayerClasses;

int g_classLimits[2][10];
TFClassType g_defaultClass[2];
float g_classSpeeds[10][3]; //0 - Base speed, 1 - Max Speed, 2 - Increment Value
float g_currentSpeed[MAXPLAYERS+1];

StringMap g_PropData;
// Multi-language support
ArrayList g_ModelLanguages;
StringMap g_PropNames;
ArrayList g_PropNamesIndex;

KeyValues g_ConfigKeyValues;
ArrayList g_ModelName;
ArrayList g_ModelOffset;
ArrayList g_ModelRotation;
ArrayList g_ModelSkin;
Handle g_Text1;
Handle g_Text2;
Handle g_Text3;
Handle g_Text4;

// PropHunt Redux Menus
//new Handle:g_RoundTimer = INVALID_HANDLE;
Menu g_PropMenu;
Menu g_ConfigMenu;

// PropHunt Redux CVars
ConVar g_PHEnable;
ConVar g_PHPropMenu;
ConVar g_PHPropMenuRestrict;
ConVar g_PHAdvertisements;
ConVar g_PHPreventFallDamage;
ConVar g_PHGameDescription;
ConVar g_PHAirblast;
ConVar g_PHAntiHack;
ConVar g_PHReroll;
ConVar g_PHStaticPropInfo;
ConVar g_PHSetupLength;
ConVar g_PHDamageBlocksPropChange;
ConVar g_PHPropMenuNames;
ConVar g_PHMultilingual;
ConVar g_PHRespawnDuringSetup;
ConVar g_PHUseUpdater;
ConVar g_PHAllowTaunts;

char g_AdText[128] = "";

bool g_MapStarted = false;

// Track optional dependencies
bool g_SteamTools = false;
bool g_SteamWorks = false;
bool g_Updater = false;

#if defined OIMM
bool g_OptinMultiMod = false;
#endif

bool g_Enabled = true;

// Timers
Handle g_hAntiHack;
Handle g_hLocked;
Handle g_hScore;

// Valve CVars we're going to save and adjust
ConVar g_hArenaRoundTime;
int g_ArenaRoundTime;
ConVar g_hWeaponCriticals;
bool g_WeaponCriticals;
ConVar g_hIdledealmethod;
int g_Idledealmethod;
ConVar g_hTournamentStopwatch;
bool g_TournamentStopwatch;
ConVar g_hTournamentHideDominationIcons;
bool g_TournamentHideDominationIcons;
ConVar g_hFriendlyfire;
bool g_Friendlyfire;
ConVar g_hGravity;
int g_Gravity;
ConVar g_hForcecamera;
int g_Forcecamera;
ConVar g_hArenaCapEnableTime;
int g_ArenaCapEnableTime;
ConVar g_hTeamsUnbalanceLimit;
int g_TeamsUnbalanceLimit;
ConVar g_hArenaMaxStreak;
int g_ArenaMaxStreak;
ConVar g_hEnableRoundWaitTime;
bool g_EnableRoundWaitTime;
ConVar g_hWaitingForPlayerTime;
int g_WaitingForPlayerTime;
ConVar g_hArenaUseQueue;
bool g_ArenaUseQueue;
ConVar g_hShowVoiceIcons;
bool g_ShowVoiceIcons;
ConVar g_hSolidObjects;
bool g_SolidObjects;
ConVar g_hArenaPreroundTime;
int g_ArenaPreroundTime;
ConVar g_hArenaFirstBlood;
bool g_ArenaFirstBlood;

ConVar g_hWeaponDropTime;
int g_WeaponDropTime;

// Regular convars
#if !defined SWITCH_TEAMS
ConVar g_hBonusRoundTime;
#endif
ConVar g_hTags;

int g_Replacements[MAXPLAYERS+1][6];
int g_ReplacementCount[MAXPLAYERS+1];
bool g_Rerolled[MAXPLAYERS+1] = { false, ... };

bool g_CvarsSet;

RoundChange g_RoundChange;

bool g_CurrentlyFlaming[MAXPLAYERS+1];
int g_FlameCount[MAXPLAYERS+1];
#define FLY_COUNT 3

int g_LastPropDamageTime[MAXPLAYERS+1] = { -1, ... };
int g_LastPropPlayer = 0;

bool g_PHMap;

bool g_RoundStartMessageSent[MAXPLAYERS+1];

// Multi-round support
int g_RoundCount = 0;
int g_RoundCurrent = 0;
int g_RoundSwitchAlways = false;

// New override support for propmenu and stuff
int g_PropMenuOldFlags = 0;
bool g_PropMenuOverrideInstalled = false;
int g_PropRerollOldFlags = 0;
bool g_PropRerollOverrideInstalled = false;

int g_GameRulesProxy = INVALID_ENT_REFERENCE;

#if defined SHINX
TFClassType g_PreferredHunterClass[MAXPLAYERS+1] = { TFClass_Unknown, ... };
#endif

// Forward for subplugins
Handle g_GameDescriptionForward;

public Plugin myinfo =
{
	name = "PropHunt Redux",
	author = "Darkimmortal, Geit, and Powerlord",
	description = "Hide as a prop from the evil Pyro menace... or hunt down the hidden prop scum",
	version = PL_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=228086"
}

// Updated in Prophunt Redux from Source SDK 2013's const.h
// https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/public/const.h
enum
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
}

#if defined STATS

#include "prophunt\stats2.inc"
/*
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	decl String:hostname[255], String:ip[32], String:port[8]; //, String:map[92];
	GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
	GetConVarString(FindConVar("ip"), ip, sizeof(ip));
	GetConVarString(FindConVar("hostport"), port, sizeof(port));

	if(StrContains(hostname, "GamingMasters.co.uk", false) != -1)
	{
		if(StrContains(hostname, "PropHunt", false) == -1 && StrContains(hostname, "Arena", false) == -1 && StrContains(hostname, "Dark", false) == -1 &&
				StrContains(ip, "8.9.4.169", false) == -1)
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}
*/
#endif

Handle g_hSwitchTeams;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		strcopy(error, err_max, "PropHunt Redux only works on Team Fortress 2.");
		return APLRes_Failure;
	}
	
	// This SHOULD be done in steamtools.inc, but isn't.
	MarkNativeAsOptional("Steam_SetGameDescription");

#if defined WORKSHOP_SUPPORT	
	// Part of SM 1.8
	MarkNativeAsOptional("GetMapDisplayName");
#endif

	CreateNative("PropHuntRedux_ValidateMap", Native_ValidateMap);
	CreateNative("PropHuntRedux_IsRunning", Native_IsRunning);
	CreateNative("PropHuntRedux_GetPropModel", Native_GetModel);
	CreateNative("PropHuntRedux_GetPropModelName", Native_GetModelName);
	CreateNative("PropHuntRedux_IsLastPropMode", Native_LastPropMode);
	
	RegPluginLibrary("prophuntredux");

	return APLRes_Success;
}

public void OnPluginStart()
{
	Handle gc;
	
#if defined SWITCH_TEAMS
	gc = LoadGameConfigFile("tf2-switch-teams");
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gc, SDKConf_Virtual, "CTFGameRules::SetSwitchTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSwitchTeams = EndPrepSDKCall();
	
#if defined LOG
	LogMessage("[PH] Created call to SetSwitchTeams at vtable offset %d", GameConfGetOffset(gc, "CTeamplayRules::SetSwitchTeams"));
#endif
	
	delete gc;
#if defined LOG
	else
	{
		LogMessage("Failed to load gamedata");
	}
#endif
#endif	
	char hostname[255], ip[32], port[8]; //, String:map[92];
	GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
	GetConVarString(FindConVar("ip"), ip, sizeof(ip));
	GetConVarString(FindConVar("hostport"), port, sizeof(port));

	Format(g_ServerIP, sizeof(g_ServerIP), "%s:%s", ip, port);

	bool statsbool = false;
#if defined STATS
	statsbool = true;
#endif

	g_hWeaponRemovals = new ArrayList();
	g_hPropWeaponRemovals = new ArrayList();
	g_hWeaponNerfs = new StringMap();
	g_hWeaponSelfDamage = new StringMap();
	g_hWeaponStripAttribs = new ArrayList();
	g_hWeaponAddAttribs = new StringMap();
	g_hWeaponReplacements = new StringMap();
	g_hWeaponReplacementPlayerClasses = new StringMap();
	
	Format(g_Version, sizeof(g_Version), "%s%s", PL_VERSION, statsbool ? "s":"");
	// PropHunt Redux now lies and pretends to be PropHunt as well
	CreateConVar("sm_prophunt_version", g_Version, "PropHunt Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("prophunt_redux_version", g_Version, "PropHunt Redux Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_PHEnable = CreateConVar("ph_enable", "1", "Enables the plugin", FCVAR_DONTRECORD);
	g_PHPropMenu = CreateConVar("ph_propmenu", "0", "Control use of the propmenu command: -1 = Disabled, 0 = admins or people with the propmenu override, 1 = all players", _, true, -1.0, true, 1.0);
	g_PHPropMenuRestrict = CreateConVar("ph_propmenurestrict", "0", "If ph_propmenu is allowed, restrict typed props to the propmenu list?  Defaults to 0 (no).", _, true, 0.0, true, 1.0);
	g_PHAdvertisements = CreateConVar("ph_adtext", g_AdText, "Controls the text used for Advertisements");
	g_PHPreventFallDamage = CreateConVar("ph_preventfalldamage", "0", "Set to 1 to prevent fall damage.  Will use TF2Attributes if available due to client prediction", _, true, 0.0, true, 1.0);
	g_PHGameDescription = CreateConVar("ph_gamedescription", "1", "If SteamTools/SteamWorks is loaded, set the Game Description to PropHunt Redux?", _, true, 0.0, true, 1.0);
	g_PHAirblast = CreateConVar("ph_airblast", "0", "Allow Pyros to airblast? Takes effect on round change unless TF2Attributes is installed.", _, true, 0.0, true, 1.0);
	g_PHAntiHack = CreateConVar("ph_antihack", "1", "Make sure props don't have weapons. Leave this on unless you're having issues with other plugins.", _, true, 0.0, true, 1.0);
	g_PHReroll = CreateConVar("ph_propreroll", "0", "Control use of the propreroll command: -1 = Disabled, 0 = admins or people with the propreroll override, 1 = all players", _, true, -1.0, true, 1.0);
	g_PHStaticPropInfo = CreateConVar("ph_staticpropinfo", "1", "Kick players who have r_staticpropinfo set to 1?", _, true, 0.0, true, 1.0);
	g_PHSetupLength = CreateConVar("ph_setuplength", "30", "Amount of setup time in seconds.", _, true, float(SETUP_MIN), true, float(SETUP_MAX));
	g_PHDamageBlocksPropChange = CreateConVar("ph_burningblockspropchange", "1", "Block Prop Change while players are bleeding, jarated, or on fire? (Fixes bugs)", _, true, 0.0, true, 1.0);
	g_PHPropMenuNames = CreateConVar("ph_propmenuusenames", "0", "Use names for Prop Menu? This is disabled by default for compatibility reasons.", _, true, 0.0, true, 1.0);
	g_PHMultilingual = CreateConVar("ph_multilingual", "0", "Use multilingual support? Uses more Handles if enabled. Disabled by default as we have no alternate languages (yet)", _, true, 0.0, true, 1.0);
	g_PHRespawnDuringSetup = CreateConVar("ph_respawnduringsetup", "1", "If a player dies during setup, should we respawn them?", _, true, 0.0, true, 1.0);
	g_PHUseUpdater = CreateConVar("ph_useupdater", "1", "Use Updater to keep PropHunt Redux up to date? Only applies if the Updater plugin is installed.", _, true, 0.0, true, 1.0);
	g_PHAllowTaunts = CreateConVar("ph_allowproptaunts", "0", "Allow props to use taunt items", _, true, 0.0, true, 1.0);
	
	// These are expensive and should be done just once at plugin start.
	g_hArenaRoundTime = FindConVar("tf_arena_round_time");
	g_hWeaponCriticals = FindConVar("tf_weapon_criticals");
	g_hIdledealmethod = FindConVar("mp_idledealmethod");
	g_hTournamentStopwatch = FindConVar("mp_tournament_stopwatch");
	g_hTournamentHideDominationIcons = FindConVar("tf_tournament_hide_domination_icons");
	g_hFriendlyfire = FindConVar("mp_friendlyfire");
	g_hGravity = FindConVar("sv_gravity");
	g_hForcecamera = FindConVar("mp_forcecamera");
	g_hArenaCapEnableTime = FindConVar("tf_arena_override_cap_enable_time");
	g_hTeamsUnbalanceLimit = FindConVar("mp_teams_unbalance_limit");
	g_hArenaMaxStreak = FindConVar("tf_arena_max_streak");
	g_hEnableRoundWaitTime = FindConVar("mp_enableroundwaittime");
	g_hWaitingForPlayerTime = FindConVar("mp_waitingforplayers_time");
	g_hArenaUseQueue = FindConVar("tf_arena_use_queue");
	g_hShowVoiceIcons = FindConVar("mp_show_voice_icons");
	g_hSolidObjects = FindConVar("tf_solidobjects");
	g_hArenaPreroundTime = FindConVar("tf_arena_preround_time");
	g_hArenaFirstBlood = FindConVar("tf_arena_first_blood");
	
	g_hWeaponDropTime = FindConVar("tf_dropped_weapon_lifetime");
	
#if !defined SWITCH_TEAMS
	g_hBonusRoundTime = FindConVar("mp_bonusroundtime");
#endif

	g_hTags = FindConVar("sv_tags");
	
	g_PHEnable.AddChangeHook(OnEnabledChanged);
	g_PHAdvertisements.AddChangeHook(OnAdTextChanged);
	g_PHGameDescription.AddChangeHook(OnGameDescriptionChanged);
	g_PHAntiHack.AddChangeHook(OnAntiHackChanged);
	g_PHStaticPropInfo.AddChangeHook(OnAntiHackChanged);
	g_PHPropMenu.AddChangeHook(OnPropMenuChanged);
	g_PHReroll.AddChangeHook(OnPropRerollChanged);
	g_PHMultilingual.AddChangeHook(OnMultilingualChanged);
	g_PHUseUpdater.AddChangeHook(OnUseUpdaterChanged);

	g_Text1 = CreateHudSynchronizer();
	g_Text2 = CreateHudSynchronizer();
	g_Text3 = CreateHudSynchronizer();
	g_Text4 = CreateHudSynchronizer();

	AddServerTag("PropHunt");

	// Events
	HookEvent("player_spawn", Event_player_spawn);
	HookEvent("player_team", Event_player_team);
	HookEvent("player_death", Event_player_death, EventHookMode_Pre);
	HookEvent("arena_round_start", Event_arena_round_start);
	HookEvent("arena_win_panel", Event_arena_win_panel);
	HookEvent("post_inventory_application", Event_post_inventory_application);
	HookEvent("teamplay_broadcast_audio", Event_teamplay_broadcast_audio, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_teamplay_round_start_pre, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_teamplay_round_start);
	HookEvent("teamplay_restart_round", Event_teamplay_restart_round);
	//HookEvent("teamplay_setup_finished", Event_teamplay_setup_finished); // No longer used since 2.0.3 or so because of issues with certain maps

#if defined STATS
	Stats_Init();
#endif

	RegConsoleCmd("help", Command_motd);
	RegConsoleCmd("phstats", Command_motd);
	RegConsoleCmd("ph_stats", Command_motd);
	RegConsoleCmd("ph_config", Command_config);
	RegConsoleCmd("ph_settings", Command_config);
	//RegConsoleCmd("motd", Command_motd);
	RegAdminCmd("propmenu", Command_propmenu, ADMFLAG_KICK, "Select a new prop from the prop menu if allowed.");
	RegAdminCmd("propreroll", Command_propreroll, ADMFLAG_KICK, "Change your prop. Useable once per round if allowed.");

	// These are now parsed from the config file itself.
	//AddFileToDownloadsTable("sound/prophunt/found.mp3");
	//AddFileToDownloadsTable("sound/prophunt/snaaake.mp3");
	//AddFileToDownloadsTable("sound/prophunt/oneandonly.mp3");
	
	LoadTranslations("prophunt.phrases");
	LoadTranslations("common.phrases");
 
	g_Sounds = CreateTrie();
	g_BroadcastSounds = CreateTrie();
	
	// Don't do this at plugin start, but on configs executed
	//loadGlobalConfig();
	
	RegAdminCmd("ph_respawn", Command_respawn, ADMFLAG_ROOT, "Respawns you");
	RegAdminCmd("ph_switch", Command_switch, ADMFLAG_BAN, "Switches to RED");
	RegAdminCmd("ph_internet", Command_internet, ADMFLAG_BAN, "Spams Internet");
	RegAdminCmd("ph_pyro", Command_pyro, ADMFLAG_BAN, "Switches to BLU");
	RegAdminCmd("ph_reloadconfig", Command_ReloadConfig, ADMFLAG_BAN, "Reloads the PropHunt configuration");

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			ForcePlayerSuicide(client);
#if defined STATS
			OnClientPostAdminCheck(client);
#endif
		}
	}
	g_PropData = CreateTrie();
	g_PropNames = CreateTrie();
	g_PropNamesIndex = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_ModelLanguages = CreateArray(ByteCountToCells(MAXLANGUAGECODE));

	g_ModelName = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_ModelOffset = CreateArray(ByteCountToCells(11));
	g_ModelRotation = CreateArray(ByteCountToCells(11));
	g_ModelSkin = CreateArray();
	
	AutoExecConfig(true, "prophunt_redux");
	
	// Create Config menu
	g_ConfigMenu = CreateMenu(Handler_ConfigMenu, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	SetMenuTitle(g_ConfigMenu, "PropHunt Configuration");
	SetMenuPagination(g_ConfigMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(g_ConfigMenu, true);
	AddMenuItem(g_ConfigMenu, "#version", PL_VERSION);
	AddMenuItem(g_ConfigMenu, "#airblast", "Airblast");
	AddMenuItem(g_ConfigMenu, "#propmenu", "PropMenu");
	AddMenuItem(g_ConfigMenu, "#proprestrict", "PropRestrict");
	AddMenuItem(g_ConfigMenu, "#propdamage", "PropChange");
	AddMenuItem(g_ConfigMenu, "#propreroll", "PropReroll");
	AddMenuItem(g_ConfigMenu, "#preventfalldamage", "Prevent Fall Damage");
	AddMenuItem(g_ConfigMenu, "#setuptime", "Setup Time");
#if defined STATS
	AddMenuItem(g_ConfigMenu, "#stats", "Stats");
#endif

	g_GameDescriptionForward = CreateGlobalForward("PropHuntRedux_UpdateGameDescription", ET_Event, Param_String);
}

void ReadCommonPropData(bool onlyLanguageRefresh = false)
{
	char Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Path, sizeof(Path), "data/prophunt/prop_common.txt");
	KeyValues propCommon = CreateKeyValues("propcommon");
	if (!propCommon.ImportFromFile(Path))
	{
		LogError("Could not load the g_PropData file!");
		return;
	}
	
	if (!propCommon.GotoFirstSubKey())
	{
		LogError("Prop Common file is empty!");
		return;
	}		
	
	ClearPropNames();
	
	if (!onlyLanguageRefresh)
	{
		g_PropData.Clear();
	}
	g_ModelLanguages.Clear();
	
	int counter = 0;
	do
	{
		counter++;
		char modelPath[PLATFORM_MAX_PATH];
		
		int propData[PropData];
		
		propCommon.GetSectionName(modelPath, sizeof(modelPath));
		propCommon.GetString("name", propData[PropData_Name], sizeof(propData[PropData_Name]), ""); // Still around for compat reasons
		if (strlen(propData[PropData_Name]) == 0)
		{
			propCommon.GetString("en", propData[PropData_Name], sizeof(propData[PropData_Name]), ""); // Default this to English otherwise
		}
		propCommon.GetString("offset", propData[PropData_Offset], sizeof(propData[PropData_Offset]), "0 0 0");
		propCommon.GetString("rotation", propData[PropData_Rotation], sizeof(propData[PropData_Rotation]), "0 0 0");

		if (strlen(propData[PropData_Name]) == 0)
		{
			// No "name" or "en" block means no prop name, but this isn't an error that prevents us from using the prop for offset and rotation
			LogError("Error getting prop name for %s", modelPath);
		}
		
		if (!onlyLanguageRefresh)
		{
			if (!g_PropData.SetArray(modelPath, propData[0], sizeof(propData), false))
			{
				LogError("Error saving prop data for %s, probably a duplicate prop in data/prophunt/prop_common.txt", modelPath);
				continue;
			}
		}
		
		if (g_PHMultilingual.BoolValue)
		{
			StringMap languageTrie = CreateTrie();
			
			for (int i=0;i<GetLanguageCount();i++)
			{
				char lang[MAXLANGUAGECODE];
				char name[MAXMODELNAME];
				GetLanguageInfo(i, lang, sizeof(lang));
				//search for the translation
				propCommon.GetString(lang, name, sizeof(name));

				// Make "en" read the "name" section for compatibility reasons if "en" isn't present
				if (strlen(name) <= 0 && StrEqual(lang, "en"))
				{
					strcopy(name, sizeof(name), propData[PropData_Name]);
				}
				
				if (strlen(name) > 0)
				{
					//language new?
					if (g_ModelLanguages.FindString(lang) == -1)
					{
#if defined LOG
						LogMessage("[PH] Adding language \"%s\" to languages list", lang);
#endif
						g_ModelLanguages.PushString(lang);
					}
					
					languageTrie.SetString(lang, name);
				}
			}
			
			if (!g_PropNames.SetValue(modelPath, languageTrie, false))
			{
				LogError("Error saving prop names for %s", modelPath);
			}
			else
			{
				g_PropNamesIndex.PushString(modelPath);
			}
		}
	} while (propCommon.GotoNextKey());
	
	delete propCommon;
	
	LogMessage("Loaded %d props from props_common.txt", counter);
#if defined LOG
	LogMessage("[PH] Loaded %d language(s)", g_ModelLanguages.Length);
#endif
	
}

void ClearPropNames()
{
	int arraySize = g_PropNamesIndex.Length;
	for (int i = 0; i < arraySize; i++)
	{
		char modelName[PLATFORM_MAX_PATH];
		StringMap languageTrie;
		g_PropNamesIndex.GetString(i, modelName, sizeof(modelName));
		if (g_PropNames.GetValue(modelName, languageTrie) && languageTrie != null)
		{
			delete languageTrie;
		}
	}
	
	g_PropNames.Clear();
	g_PropNamesIndex.Clear();
}

public void OnAllPluginsLoaded()
{
	g_SteamTools = LibraryExists("SteamTools");
	g_SteamWorks = LibraryExists("SteamWorks");
	if (g_SteamTools || g_SteamWorks)
	{
#if defined LOG
		if (g_SteamTools)
			LogMessage("[PH] Found SteamTools on startup.");
			
		if (g_SteamWorks)
			LogMessage("[PH] Found SteamWorks on startup.");
#endif
		UpdateGameDescription();
	}
	
#if defined OIMM
	g_OptinMultiMod = LibraryExists("optin_multimod");
	if (g_OptinMultiMod)
	{
#if defined LOG
		LogMessage("[PH] Found Opt-In Multimod on startup.");
#endif
		OptInMultiMod_Register("prophunt", ValidateMap, MultiMod_Status, MultiMod_TranslateName);
	}
#endif

	g_Updater = LibraryExists("updater");
	
#if defined LOG
	if (g_Updater)
	{
		LogMessage("[PH] Found Updater on startup.");
	}
#endif
}

// Should we switch teams this round?
// Note: Don't confuse this with the games ShouldSwitchTeams
bool Internal_ShouldSwitchTeams()
{
	bool lastRound = (g_RoundCurrent == g_RoundCount);
	if (lastRound)
	{
#if defined LOG
	LogMessage("[PH] This is the last of %d round(s).", g_RoundCount);
#endif
		g_RoundCurrent = 0;
	}
	
	if (g_RoundSwitchAlways || lastRound)
	{
		return true;
	}
	
#if defined LOG
	LogMessage("[PH] Teams will not be switched because it is not the last round and we are set to not always switch rounds.");
#endif

	return false;
}

void loadGlobalConfig()
{
	char Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Path, sizeof(Path), "data/prophunt/prophunt_config.cfg");
	if (g_ConfigKeyValues != null)
	{
		delete g_ConfigKeyValues;
	}
	g_ConfigKeyValues = CreateKeyValues("prophunt_config");
	if (!g_ConfigKeyValues.ImportFromFile(Path))
	{
		LogError("Could not load the PropHunt config file!");
	}
	
	config_parseWeapons();
	config_parseClasses();
	config_parseSounds();
	
	ReadCommonPropData(false);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "SteamTools", false))
	{
#if defined LOG
		LogMessage("[PH] SteamTools Loaded ");
#endif
		g_SteamTools = true;
		UpdateGameDescription();
	}
	else
	if (StrEqual(name, "SteamWorks", false))
	{
#if defined LOG
		LogMessage("[PH] SteamWorks Loaded ");
#endif
		g_SteamWorks = true;
		UpdateGameDescription();
	}
#if defined OIMM
	else
	if (StrEqual(name, "optin_multimod", false))
	{
#if defined LOG
		LogMessage("[PH] Opt-in MultiMod Loaded ");
#endif
		g_OptinMultiMod = true;
	}
#endif
	else
	if (StrEqual(name, "updater", false))
	{
#if defined LOG
		LogMessage("[PH] Updater Loaded.");
#endif
		g_Updater = true;
		Updater_AddPlugin(UPDATE_URL);
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "SteamTools", false))
	{
#if defined LOG
		LogMessage("[PH] SteamTools Unloaded ");
#endif
		g_SteamTools = false;
	}
	else
	if (StrEqual(name, "SteamWorks", false))
	{
#if defined LOG
		LogMessage("[PH] SteamWorks Unloaded ");
#endif
		g_SteamWorks = false;
	}
#if defined OIMM
	else
	if (StrEqual(name, "optin_multimod", false))
	{
#if defined LOG
		LogMessage("[PH] Opt-In Multimod Unloaded ");
#endif
		g_OptinMultiMod = false;
	}
#endif
	else
	if (StrEqual(name, "updater", false))
	{
#if defined LOG
		LogMessage("[PH] Updater Unloaded.");
#endif
		g_Updater = false;
	}	
}

public void OnGameDescriptionChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateGameDescription();
}

public void OnAntiHackChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_Enabled)
		return;
	
	if (g_PHAntiHack.BoolValue || g_PHStaticPropInfo.BoolValue && g_hAntiHack == null)
	{
		g_hAntiHack = CreateTimer(7.0, Timer_AntiHack, _, TIMER_REPEAT);
		// Also run said timer 0.1 seconds after round start.
		CreateTimer(0.1, Timer_AntiHack, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (!g_PHAntiHack.BoolValue && !g_PHStaticPropInfo.BoolValue && g_hAntiHack != null)
	{
		delete g_hAntiHack;
	}
}

void UpdateGameDescription(bool bAddOnly=false)
{
	if (!g_SteamTools && !g_SteamWorks)
	{
		return;
	}
	
	char gamemode[128];
	if (g_Enabled && g_PHGameDescription.BoolValue)
	{
		if (strlen(g_AdText) > 0)
		{
			Format(gamemode, sizeof(gamemode), "PropHunt Redux %s (%s)", g_Version, g_AdText);
		}
		else
		{
			Format(gamemode, sizeof(gamemode), "PropHunt Redux %s", g_Version);
		}

		// Global forward for subplugins to change the game description.
		Action result = Plugin_Continue;
		char tempGamemode[128];
		strcopy(tempGamemode, sizeof(tempGamemode), gamemode);
		Call_StartForward(g_GameDescriptionForward);
		Call_PushStringEx(tempGamemode, sizeof(tempGamemode), SM_PARAM_COPYBACK, SM_PARAM_STRING_COPY);
		Call_Finish(result);
		if (result == Plugin_Changed)
		{
			strcopy(gamemode, sizeof(gamemode), tempGamemode);
		}
	}
	else if (bAddOnly)
	{
		// Leave it alone if we're not running, should only be used when configs are executed
		return;
	}
	else
	{
		strcopy(gamemode, sizeof(gamemode), "Team Fortress");
	}
	
	
	
	if (g_SteamTools)
	{
		Steam_SetGameDescription(gamemode);
	}
	else
	if (g_SteamWorks)
	{
		SteamWorks_SetGameDescription(gamemode);
	}
}

void config_parseWeapons()
{
	g_hWeaponRemovals.Clear();
	g_hPropWeaponRemovals.Clear();
	g_hWeaponNerfs.Clear();
	g_hWeaponSelfDamage.Clear();
	g_hWeaponStripAttribs.Clear();
	g_hWeaponAddAttribs.Clear();
	g_hWeaponReplacements.Clear();
	g_hWeaponReplacementPlayerClasses.Clear();
	
	if (g_ConfigKeyValues == null)
	{
		return;
	}
	
	while(g_ConfigKeyValues.GoBack())
	{
		continue;
	}
	
	if(g_ConfigKeyValues.JumpToKey("items"))
	{
		do
		{
			char SectionName[128];
			g_ConfigKeyValues.GotoFirstSubKey();
			g_ConfigKeyValues.GetSectionName(SectionName, sizeof(SectionName));
			if(g_ConfigKeyValues.GetDataType("damage_hunters") == KvData_Float)
			{
				g_hWeaponNerfs.SetValue(SectionName, g_ConfigKeyValues.GetFloat("damage_hunters"));
			}
			if(g_ConfigKeyValues.GetDataType("removed_hunters") == KvData_Int)
			{
				if (g_ConfigKeyValues.GetNum("removed_hunters"))
				{
					g_hWeaponRemovals.Push(StringToInt(SectionName));
				}
			}
			if(g_ConfigKeyValues.GetDataType("removed_props") == KvData_Int)
			{
				if (g_ConfigKeyValues.GetNum("removed_props"))
				{
					g_hPropWeaponRemovals.Push(StringToInt(SectionName));
				}
			}
			if(g_ConfigKeyValues.GetDataType("self_damage_hunters") == KvData_Float)
			{
				g_hWeaponSelfDamage.SetValue(SectionName, KvGetFloat(g_ConfigKeyValues, "self_damage_hunters"));
			}
			if(g_ConfigKeyValues.GetDataType("stripattribs") == KvData_Int)
			{
				if (g_ConfigKeyValues.GetNum("stripattribs"))
				{
					g_hWeaponStripAttribs.Push(StringToInt(SectionName));
				}
			}
			if(g_ConfigKeyValues.GetDataType("addattribs") == KvData_String)
			{
				char attribs[128];
				g_ConfigKeyValues.GetString("addattribs", attribs, sizeof(attribs));
				
				if (attribs[0] != '\0')
				{
					g_hWeaponAddAttribs.SetString(SectionName, attribs);
				}
			}
			if(g_ConfigKeyValues.GetDataType("replace") == KvData_String)
			{
				char attribs[128];
				g_ConfigKeyValues.GetString("replace", attribs, sizeof(attribs));
				
				int class = g_ConfigKeyValues.GetNum("replace_onlyclasses", TFClassBits_None);
				
				if (attribs[0] != '\0')
				{
					g_hWeaponReplacements.SetString(SectionName, attribs);
				}
				
				if (class != TFClassBits_None)
				{
					g_hWeaponReplacementPlayerClasses.SetValue(SectionName, class);
				}
			}
		}
		while(g_ConfigKeyValues.GotoNextKey());
	}
	else
	{
		LogMessage("[PH] Invalid config! Could not access subkey: items");
	}
}

void config_parseClasses()
{
	int red = TEAM_PROP-2;
	int blue = TEAM_HUNTER-2;
	g_defaultClass[red] = TFClass_Scout;
	g_defaultClass[blue] = TFClass_Pyro;
	
	for(int i = 0; i < 10; i++)
	{
		g_classLimits[blue][i] = -1;
		g_classLimits[red][i] = -1;
		g_classSpeeds[i][0] = 300.0;
		g_classSpeeds[i][1] = 400.0;
		g_classSpeeds[i][2] = 15.0;
	}
	
	if (g_ConfigKeyValues == null)
	{
		return;
	}
	
	while(g_ConfigKeyValues.GoBack())
	{
		continue;
	}
	
	if(g_ConfigKeyValues.JumpToKey("classes"))
	{
		do
		{
			char SectionName[128];
			g_ConfigKeyValues.GotoFirstSubKey();
			g_ConfigKeyValues.GetSectionName(SectionName, sizeof(SectionName));
			if(g_ConfigKeyValues.GetDataType("hunter_limit") == KvData_Int)
			{
				g_classLimits[blue][StringToInt(SectionName)] = g_ConfigKeyValues.GetNum("hunter_limit");
			}
			if(g_ConfigKeyValues.GetDataType("prop_limit") == KvData_Int)
			{
				g_classLimits[red][StringToInt(SectionName)] = g_ConfigKeyValues.GetNum("prop_limit");
			}
			if(g_ConfigKeyValues.GetDataType("hunter_default_class") == KvData_Int)
			{
				g_defaultClass[blue] = view_as<TFClassType>(StringToInt(SectionName));
			}
			if(g_ConfigKeyValues.GetDataType("prop_default_class") == KvData_Int)
			{
				g_defaultClass[red] = view_as<TFClassType>(StringToInt(SectionName));
			}
			if(g_ConfigKeyValues.GetDataType("base_speed") == KvData_Float)
			{
				g_classSpeeds[StringToInt(SectionName)][0] = g_ConfigKeyValues.GetFloat("base_speed");
			}
			if(g_ConfigKeyValues.GetDataType("max_speed") == KvData_Float)
			{
				g_classSpeeds[StringToInt(SectionName)][1] = g_ConfigKeyValues.GetFloat("max_speed");
			}
			if(g_ConfigKeyValues.GetDataType("speed_increment") == KvData_Float)
			{
				g_classSpeeds[StringToInt(SectionName)][2] = g_ConfigKeyValues.GetFloat("speed_increment");
			}
			
		}
		while(g_ConfigKeyValues.GotoNextKey());
	}
	else
	{
		LogMessage("[PH] Invalid config! Could not access subkey: classes");
	}
}

void config_parseSounds()
{
	g_Sounds.Clear();
	g_BroadcastSounds.Clear();
	
	if (g_ConfigKeyValues == null)
	{
		return;
	}
	
	while(g_ConfigKeyValues.GoBack())
	{
		continue;
	}
	
	if(g_ConfigKeyValues.JumpToKey("sounds"))
	{
		do
		{
			char SectionName[128];
			g_ConfigKeyValues.GotoFirstSubKey();
			g_ConfigKeyValues.GetSectionName(SectionName, sizeof(SectionName));
			if(g_ConfigKeyValues.GetDataType("sound") == KvData_String)
			{
				char soundString[PLATFORM_MAX_PATH];
				g_ConfigKeyValues.GetString("sound", soundString, sizeof(soundString));
				
				if(PrecacheSound(soundString))
				{
					char downloadString[PLATFORM_MAX_PATH];
					Format(downloadString, sizeof(downloadString), "sound/%s", soundString);
					AddFileToDownloadsTable(downloadString);
					
					g_Sounds.SetString(SectionName, soundString, true);
				}
			}
			if(g_ConfigKeyValues.GetDataType("broadcast") == KvData_String)
			{
				char soundString[128];
				g_ConfigKeyValues.GetString("broadcast", soundString, sizeof(soundString));
				
				PrecacheScriptSound(soundString);
				
				g_BroadcastSounds.SetString(SectionName, soundString, true);
			}
			if(g_ConfigKeyValues.GetDataType("game") == KvData_String)
			{
				char soundString[128];
				g_ConfigKeyValues.GetString("game", soundString, sizeof(soundString));
				
				PrecacheScriptSound(soundString);
				
				g_BroadcastSounds.SetString(SectionName, soundString, true);
			}
		}
		while(g_ConfigKeyValues.GotoNextKey());
	}
	else
	{
		LogMessage("[PH] Invalid config! Could not access subkey: sounds");
	}
}

void SetCVars(){

	g_hArenaRoundTime.Flags = g_hArenaRoundTime.Flags & ~FCVAR_NOTIFY;
	g_hArenaUseQueue.Flags = g_hArenaUseQueue.Flags & ~FCVAR_NOTIFY;
	g_hArenaMaxStreak.Flags = g_hArenaMaxStreak.Flags & ~FCVAR_NOTIFY;
	g_hTournamentStopwatch.Flags = g_hTournamentStopwatch.Flags & ~FCVAR_NOTIFY;
	g_hTournamentHideDominationIcons.Flags = g_hTournamentHideDominationIcons.Flags & ~FCVAR_NOTIFY;
	g_hTeamsUnbalanceLimit.Flags = g_hTeamsUnbalanceLimit.Flags & ~FCVAR_NOTIFY;
	g_hArenaPreroundTime.Flags = g_hArenaPreroundTime.Flags & ~FCVAR_NOTIFY;

	g_ArenaRoundTime = g_hArenaRoundTime.IntValue;
	g_hArenaRoundTime.IntValue = 0;
	
	g_ArenaUseQueue = g_hArenaUseQueue.BoolValue;
	g_hArenaUseQueue.BoolValue = false;

	g_ArenaMaxStreak = g_hArenaMaxStreak.IntValue;
	g_hArenaMaxStreak.IntValue = 2;
	
	g_TournamentStopwatch = g_hTournamentStopwatch.BoolValue;
	g_hTournamentStopwatch.BoolValue = false;
	
	g_TournamentHideDominationIcons = g_hTournamentHideDominationIcons.BoolValue;
	g_hTournamentHideDominationIcons.BoolValue = true;

	g_TeamsUnbalanceLimit = g_hTeamsUnbalanceLimit.IntValue;
	g_hTeamsUnbalanceLimit.IntValue = UNBALANCE_LIMIT;

	
	g_hArenaPreroundTime.SetBounds(ConVarBound_Upper, false);
	g_ArenaPreroundTime = g_hArenaPreroundTime.IntValue;
	g_hArenaPreroundTime.IntValue = IsDedicatedServer() ? 20 : 5;
	
	g_WeaponCriticals = g_hWeaponCriticals.BoolValue;
	g_hWeaponCriticals.BoolValue = false;
	
	// Idle Deal Method is buggy on Arena sometimes
	g_Idledealmethod = g_hIdledealmethod.IntValue;
	g_hIdledealmethod.IntValue = 0;
	
	g_Friendlyfire = g_hFriendlyfire.BoolValue;
	g_hFriendlyfire.BoolValue = false;
	
	// Lower gravity to 500 for PropHunt
	g_Gravity = g_hGravity.IntValue;
	g_hGravity.IntValue = 500;
	
	g_Forcecamera = g_hForcecamera.IntValue;
	g_hForcecamera.IntValue = 1;
	
	g_ArenaCapEnableTime = g_hArenaCapEnableTime.IntValue;
	g_hArenaCapEnableTime.IntValue = 3600; // Set really high
	
	g_EnableRoundWaitTime = g_hEnableRoundWaitTime.BoolValue;
	g_hEnableRoundWaitTime.BoolValue = false;

	g_WaitingForPlayerTime = g_hWaitingForPlayerTime.IntValue;
	g_hWaitingForPlayerTime.IntValue = 40;
	
	g_ShowVoiceIcons = g_hShowVoiceIcons.BoolValue;
	g_hShowVoiceIcons.BoolValue = false;

	g_SolidObjects = g_hSolidObjects.BoolValue;
	g_hSolidObjects.BoolValue = false;
	
	g_ArenaFirstBlood = g_hArenaFirstBlood.BoolValue;
	g_hArenaFirstBlood.BoolValue = false;
	
	// Force weapons to immediately vanish when dropped
	g_WeaponDropTime = g_hWeaponDropTime.IntValue;
	g_hWeaponDropTime.IntValue = 0;
	
	g_CvarsSet = true;
}

void ResetCVars()
{
	if (!g_CvarsSet)
		return;
	
	g_hArenaRoundTime.Flags = g_hArenaRoundTime.Flags & ~FCVAR_NOTIFY;
	g_hArenaUseQueue.Flags = g_hArenaUseQueue.Flags & ~FCVAR_NOTIFY;
	g_hArenaMaxStreak.Flags = g_hArenaMaxStreak.Flags & ~FCVAR_NOTIFY;
	g_hTournamentStopwatch.Flags = g_hTournamentStopwatch.Flags & ~FCVAR_NOTIFY;
	g_hTournamentHideDominationIcons.Flags = g_hTournamentHideDominationIcons.Flags & ~FCVAR_NOTIFY;
	g_hTeamsUnbalanceLimit.Flags = g_hTeamsUnbalanceLimit.Flags & ~FCVAR_NOTIFY;
	g_hArenaPreroundTime.Flags = g_hArenaPreroundTime.Flags & ~FCVAR_NOTIFY;
	
	g_hArenaRoundTime.IntValue = g_ArenaRoundTime;
	g_hArenaUseQueue.BoolValue = g_ArenaUseQueue;
	g_hArenaMaxStreak.IntValue = g_ArenaMaxStreak;
	g_hTournamentStopwatch.BoolValue = g_TournamentStopwatch;
	g_hTournamentHideDominationIcons.BoolValue = g_TournamentHideDominationIcons;
	g_hTeamsUnbalanceLimit.IntValue = g_TeamsUnbalanceLimit;
	g_hArenaPreroundTime.IntValue = g_ArenaPreroundTime;
	g_hWeaponCriticals.BoolValue = g_WeaponCriticals;
	g_hIdledealmethod.IntValue = g_Idledealmethod;
	g_hFriendlyfire.BoolValue = g_Friendlyfire;
	g_hGravity.IntValue = g_Gravity;
	g_hForcecamera.IntValue = g_Forcecamera;
	g_hArenaCapEnableTime.IntValue = g_ArenaCapEnableTime;
	g_hEnableRoundWaitTime.BoolValue = g_EnableRoundWaitTime;
	g_hWaitingForPlayerTime.IntValue = g_WaitingForPlayerTime;
	g_hShowVoiceIcons.BoolValue = g_ShowVoiceIcons;
	g_hSolidObjects.BoolValue = g_SolidObjects;
	g_hArenaFirstBlood.BoolValue = g_ArenaFirstBlood;
	g_hWeaponDropTime.IntValue = g_WeaponDropTime;
	
	g_CvarsSet = false;
}

public void OnConfigsExecuted()
{
	g_Enabled = g_PHEnable.BoolValue && g_PHMap;
	
	g_GameRulesProxy = EntIndexToEntRef(FindEntityByClassname(-1, "tf_gamerules"));
	
	if (g_PHPropMenu.IntValue == 1 && !g_PropMenuOverrideInstalled)
	{
		InstallPropMenuOverride();
	}
	
	if (g_PHReroll.IntValue == 1 && !g_PropRerollOverrideInstalled)
	{
		InstallPropRerollOverride();
	}
	
	if (g_Enabled)
	{
		SetCVars();
		Internal_AddServerTag();
	}
	else
	{
		Internal_RemoveServerTag();
	}
	
	UpdateGameDescription(true);
	
	CountRounds();
}

void InstallPropMenuOverride()
{
	int tempFlags;
	if (GetCommandOverride("propmenu", Override_Command, tempFlags))
	{
		g_PropMenuOldFlags = tempFlags;
	}
	
	AddCommandOverride("propmenu", Override_Command, ADMFLAG_NONE);
	g_PropMenuOverrideInstalled = true;
}

void RemovePropMenuOverride()
{
	if (g_PropMenuOldFlags == ADMFLAG_NONE)
	{
		UnsetCommandOverride("propmenu", Override_Command);
	}
	else
	{
		AddCommandOverride("propmenu", Override_Command, g_PropMenuOldFlags);
		g_PropMenuOldFlags = ADMFLAG_NONE;
	}
	
	g_PropMenuOverrideInstalled = false;
}

void InstallPropRerollOverride()
{
	int tempFlags;
	if (GetCommandOverride("propreroll", Override_Command, tempFlags))
	{
		g_PropRerollOldFlags = tempFlags;
	}
	
	AddCommandOverride("propreroll", Override_Command, ADMFLAG_NONE);
	g_PropRerollOverrideInstalled = true;
}

void RemovePropRerollOverride()
{
	if (g_PropRerollOldFlags == ADMFLAG_NONE)
	{
		UnsetCommandOverride("propreroll", Override_Command);
	}
	else
	{
		AddCommandOverride("propreroll", Override_Command, g_PropRerollOldFlags);
		g_PropRerollOldFlags = ADMFLAG_NONE;
	}
	
	g_PropRerollOverrideInstalled = false;
}

public void OnPropMenuChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int newVal = g_PHPropMenu.IntValue;
	if (g_PropMenuOverrideInstalled && newVal < 1)
	{
		RemovePropMenuOverride();
	}
	else if (!g_PropMenuOverrideInstalled && newVal == 1)
	{
		InstallPropMenuOverride();
	}
}

public void OnPropRerollChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int newVal = g_PHReroll.IntValue;
	if (g_PropRerollOverrideInstalled && newVal < 1)
	{
		RemovePropRerollOverride();
	}
	else if (!g_PropRerollOverrideInstalled && newVal == 1)
	{
		InstallPropRerollOverride();
	}
}

public void OnMultilingualChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.BoolValue)
	{
		ReadCommonPropData(true);
	}
	else
	{
		ClearPropNames();
	}
	
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if (part == AdminCache_Overrides && (g_PHPropMenu.IntValue == 1 || g_PHReroll.IntValue == 1))
	{
		CreateTimer(0.2, Timer_RestoreOverrides);
	}
}

public Action Timer_RestoreOverrides(Handle timer)
{
	if (g_PHPropMenu.IntValue == 1)
	{
		InstallPropMenuOverride();
	}
	
	if (g_PHReroll.IntValue == 1)
	{
		InstallPropRerollOverride();
	}
}

void CountRounds()
{
	g_RoundCurrent = 0;
	g_RoundCount = 0;
	int entity = -1;
//	new prevPriority = 0;
	bool roundSwitchAlways = true;
	
	while ((entity = FindEntityByClassname(entity, "team_control_point_round")) != -1)
	{
		// Check if the round isn't disabled here?
		// Test on ph_kakariko to see if its other part is present.
		g_RoundCount++;
		// We'll look at round priorities again sometime in the future, ignore for now.
		/*
		new priority = GetEntProp(entity, Prop_Data, "m_nPriority");
		if (prevPriority == 0)
		{
			prevPriority = priority;
		}
		else
		if (prevPriority != priority)
		{
			
			roundSwitchAlways = false;
			break;
		}
		*/
	}
	
	// No team_control_point_round entities means we have just 1 round
	if (g_RoundCount == 0)
		g_RoundCount = 1;

	if (g_RoundCount % 2 == 0)
	{
		// For event number of rounds, never switch
		roundSwitchAlways = false;
	}
	
	g_RoundSwitchAlways = roundSwitchAlways;
	
#if defined LOG
	LogMessage("[PH] Map has %d round(s), Switch teams every round: %d", g_RoundCount, g_RoundSwitchAlways);
#endif
}


void StartTimers(bool noScoreTimer = false)
{
	if (g_hLocked == null)
	{
		g_hLocked = CreateTimer(0.6, Timer_Locked, _, TIMER_REPEAT);
	}
		
	if (!noScoreTimer && g_hScore == null)
	{
		g_hScore = CreateTimer(55.0, Timer_Score, _, TIMER_REPEAT);
	}

	if ((g_PHAntiHack.BoolValue || g_PHStaticPropInfo.BoolValue) && g_hAntiHack == null)
	{
		g_hAntiHack = CreateTimer(7.0, Timer_AntiHack, _, TIMER_REPEAT);
		// Also run said timer 0.1 seconds after round start.
		CreateTimer(0.1, Timer_AntiHack, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void StopTimers()
{
	if (g_hAntiHack != null)
	{
		delete g_hAntiHack;
	}
	
	if (g_hLocked != null)
	{
		delete g_hLocked;
	}
	
	if (g_hScore != null)
	{
		delete g_hScore;
	}
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_MapStarted)
	{
		return;
	}
	
	if (g_PHEnable.BoolValue)
	{
		if (g_Enabled)
		{
			g_RoundChange = RoundChange_NoChange; // Reset in case it was RoundChange_Disable
		}
		else
		{
			bool enabled = IsPropHuntMap();
			if (enabled)
			{
				g_RoundChange = RoundChange_Enable;
			}
			else
			{
				g_RoundChange = RoundChange_NoChange;
			}
		}
	}
	else
	{
		if (g_Enabled)
		{
			g_RoundChange = RoundChange_Disable;
		}
		else
		{
			g_RoundChange = RoundChange_NoChange;
		}
	}
}

public void OnAdTextChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(g_AdText, sizeof(g_AdText), newValue);
}

public void OnUseUpdaterChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_Updater)
		return;
		
	if (convar.BoolValue)
	{
		Updater_ForceUpdate();
	}
}

public Action Updater_OnPluginDownloading()
{
	return g_PHUseUpdater.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public int Updater_OnPluginUpdated()
{
	PrintCenterTextAll("PropHunt Redux Updated, server restart may be required.");
	LogMessage("PropHunt Redux Updated, server restart may be required.");
}

public void StartTouchHook(int entity, int other)
{
	if(other <= MaxClients && other > 0 && !g_TouchingCP[other] && IsClientInGame(other) && IsPlayerAlive(other))
	{
		FillHealth(other);
		ExtinguishPlayer(other);
		CPrintToChat(other, "%t", "#TF_PH_CPBonus");
		PH_EmitSoundToClient(other, "CPBonus", _, _, SNDLEVEL_AIRCRAFT);
		g_TouchingCP[other] = true;
	}
}

stock void FillHealth (int entity)
{
	if(IsValidEntity(entity))
	{
		SetEntityHealth(entity, GetEntProp(entity, Prop_Data, "m_iMaxHealth"));
	}
}

stock void ExtinguishPlayer (int client){
	if(IsClientInGame(client) && IsPlayerAlive(client) && IsValidEntity(client))
	{
		ExtinguishEntity(client);
		TF2_RemoveCondition(client, TFCond_OnFire);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_Enabled)
	{
		return;
	}
	/*
	if(strcmp(classname, "team_control_point") == 0 ||
		strcmp(classname, "team_control_point_round") == 0 ||
		strcmp(classname, "trigger_capture_area") == 0 ||
		strcmp(classname, "func_respawnroom") == 0 ||
		strcmp(classname, "func_respawnroomvisualizer") == 0 ||
		strcmp(classname, "obj_sentrygun") == 0)
	{
		SDKHook(entity, SDKHook_Spawn, OnBullshitEntitySpawned);
	}
	else
	*/
	if (strcmp(classname, "obj_sentrygun") == 0)
	{
		SDKHook(entity, SDKHook_Spawn, OnBullshitEntitySpawned);
	}
	else
	if(strcmp(classname, "prop_dynamic") == 0 || strcmp(classname, "prop_static") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnCPEntitySpawned);
	}
	else
	if(strcmp(classname, "team_control_point_master") == 0)
	{
		SDKHook(entity, SDKHook_Spawn, OnCPMasterSpawned);
		SDKHook(entity, SDKHook_SpawnPost, OnCPMasterSpawnedPost);
	}
	else
	if (strcmp(classname, "team_round_timer") == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnTimerSpawned);
	}
}

public Action OnBullshitEntitySpawned(int entity)
{
	if(IsValidEntity(entity))
		AcceptEntityInput(entity, "Kill");
	
	return Plugin_Continue;
}

public void OnCPEntitySpawned(int entity)
{
	char propName[500];
	GetEntPropString(entity, Prop_Data, "m_ModelName", propName, sizeof(propName));
	if(StrEqual(propName, "models/props_gameplay/cap_point_base.mdl"))
	{
		// Reset the skin to neutral.  I'm looking at you, cp_manor_event
		SetVariantInt(0);
		AcceptEntityInput(entity, "Skin");
		// Also, hook it for the heal touch hook
		SDKHook(entity, SDKHook_StartTouch, StartTouchHook);
	}
}

public Action OnTimerSpawned(int entity)
{
	// Attempt to shut the pre-round timer up at start, unless 5 secs or less are left
	char name[64];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	
	if (!StrEqual(name, TIMER_NAME))
	{
		DispatchKeyValue(entity, "auto_countdown", "0");
		
		SetVariantString("On10SecRemain !self:AutoCountdown:1:0:-1");
		AcceptEntityInput(entity, "AddOutput");

		// Client always plays the bell when the status changes from "setup" to "normal", 
		// which is what the pregame timer apparently does
		//SetVariantString("On1SecRemain !self:AutoCountdown:0:0:-1");
		//AcceptEntityInput(entity, "AddOutput");
	}
}

public Action OnCPMasterSpawned(int entity)
{
#if defined LOG
	LogMessage("[PH] cpmaster spawned");
#endif
    
	DispatchKeyValue(entity, "switch_teams", "0"); // Changed in 3.0.0 beta 6, now forced off instead of on. Ignored because SetWinner overrides it
	
	return Plugin_Continue;
}

public void OnCPMasterSpawnedPost(int entity)
{
	if (!g_MapStarted)
	{
		return;
	}
	
	int arenaLogic = FindEntityByClassname(-1, "tf_logic_arena");
	if (arenaLogic == -1)
	{
		return;
	}
	
	// We need to subtract 30 from the round time for compatibility with older PropHunt Versions
	char time[5];
	IntToString(g_RoundTime - 30, time, sizeof(time));
	
	char name[64];
	if (GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name)) == 0)
	{
		DispatchKeyValue(entity, "targetname", "master_control_point");
		strcopy(name, sizeof(name), "master_control_point");
	}
	
	// Create our timer.
	int timer = CreateEntityByName("team_round_timer");
	DispatchKeyValue(timer, "targetname", TIMER_NAME);
	char setupLength[5];
	if (g_Setup >= SETUP_MIN && g_Setup <= SETUP_MAX)
	{
		IntToString(g_Setup, setupLength, sizeof(setupLength));
	}
	else
	{
		g_PHSetupLength.GetString(setupLength, sizeof(setupLength));		
	}
	DispatchKeyValue(timer, "setup_length", setupLength);
	DispatchKeyValue(timer, "reset_time", "1");
	DispatchKeyValue(timer, "auto_countdown", "1");
	DispatchKeyValue(timer, "timer_length", time);
	DispatchSpawn(timer);
	
#if defined LOG
	LogMessage("[PH] setting up cpmaster \"%s\" (%d) with team round timer \"%s\" (%d) ", name, entity, TIMER_NAME, timer);
#endif
    
	char finishedCommand[256];
	
	Format(finishedCommand, sizeof(finishedCommand), "OnFinished %s:SetWinnerAndForceCaps:%d:0:-1", name, TEAM_PROP);
	SetVariantString(finishedCommand);
	AcceptEntityInput(timer, "AddOutput");
	
	Format(finishedCommand, sizeof(finishedCommand), "OnArenaRoundStart %s:ShowInHUD:1:0:-1", TIMER_NAME);
	SetVariantString(finishedCommand);
	AcceptEntityInput(arenaLogic, "AddOutput");
	
	Format(finishedCommand, sizeof(finishedCommand), "OnArenaRoundStart %s:Resume:0:0:-1", TIMER_NAME);
	SetVariantString(finishedCommand);
	AcceptEntityInput(arenaLogic, "AddOutput");
	
	Format(finishedCommand, sizeof(finishedCommand), "OnArenaRoundStart %s:Enable:0:0:-1", TIMER_NAME);
	SetVariantString(finishedCommand);
	AcceptEntityInput(arenaLogic, "AddOutput");
	
	HookSingleEntityOutput(timer, "OnSetupStart", OnSetupStart);
	HookSingleEntityOutput(timer, "OnSetupFinished", OnSetupFinished);
}

public void OnMapEnd()
{
#if defined STATS
	g_MapChanging = true;
#endif

	// workaround for CreateEntityByName
	g_MapStarted = false;
	
	ResetCVars();
	StopTimers();
	bool remove = g_Enabled; // Save the enabled value
	g_Enabled = false;
	if (remove)
	{
		UpdateGameDescription();
	}
	
	for (int client = 1; client<=MaxClients; client++)
	{
		g_CurrentlyFlaming[client] = false;
		g_FlameCount[client] = 0;
	}

	g_ModelName.Clear();
	g_ModelOffset.Clear();
	g_ModelRotation.Clear();
	g_ModelSkin.Clear();

	g_hWeaponRemovals.Clear();
	g_hPropWeaponRemovals.Clear();
	g_hWeaponNerfs.Clear();
	g_hWeaponSelfDamage.Clear();
	g_hWeaponStripAttribs.Clear();
	g_hWeaponAddAttribs.Clear();
	g_hWeaponReplacements.Clear();
	g_hWeaponReplacementPlayerClasses.Clear();
	
	g_Sounds.Clear();
	g_BroadcastSounds.Clear();
}

public void OnMapStart()
{
	g_GameRulesProxy = INVALID_ENT_REFERENCE;
	GetCurrentMap(g_Mapname, sizeof(g_Mapname));
	
	g_PHMap = IsPropHuntMap();

	if (g_PHMap)
	{
		char confil[PLATFORM_MAX_PATH], buffer[256], offset[32], rotation[32];
		
		KeyValues fl;
		
		if (g_PropMenu != null)
		{
			delete g_PropMenu;
		}
		g_PropMenu = new Menu(Handler_PropMenu, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
		g_PropMenu.SetTitle("PropHunt Prop Menu");
		g_PropMenu.ExitButton = true;
		
		BuildPath(Path_SM, confil, sizeof(confil), "data/prophunt/prop_menu.txt");
		
		fl = CreateKeyValues("propmenu");
		if (fl.ImportFromFile(confil))
		{
			int count = 0;
			PrintToServer("Successfully loaded %s", confil);
			fl.GotoFirstSubKey();
			do
			{
				fl.GetSectionName(buffer, sizeof(buffer));
				if (!FileExists(buffer, true))
				{
					LogError("prop_menu.txt: Prop does not exist: %s", buffer);
					continue;
				}
				g_PropMenu.AddItem(buffer, buffer);
				count++;
			}
			while (fl.GotoNextKey());
			
			PrintToServer("Successfully parsed %s", confil);
			PrintToServer("Added %i models to prop menu.", GetMenuItemCount(g_PropMenu));
		}
		delete fl;
		
		int sharedCount = 0;
		BuildPath(Path_SM, confil, sizeof(confil), "data/prophunt/props_allmaps.txt");
		
		fl = CreateKeyValues("sharedprops");
		if (fl.ImportFromFile(confil))
		{
			PrintToServer("Successfully loaded %s", confil);
			fl.GotoFirstSubKey();
			do
			{
				fl.GetSectionName(buffer, sizeof(buffer));
				if (!FileExists(buffer, true))
				{
					LogError("props_allmaps.txt: Prop does not exist: %s", buffer);
					continue;
				}
				g_ModelName.PushString(buffer);
				g_PropMenu.AddItem(buffer, buffer);
				fl.GetString("offset", offset, sizeof(offset), "0 0 0");
				g_ModelOffset.PushString(offset);
				fl.GetString("rotation", rotation, sizeof(rotation), "0 0 0");
				g_ModelRotation.PushString(rotation);
				g_ModelSkin.Push(KvGetNum(fl, "skin", 0));
			}
			while (fl.GotoNextKey());
			
			PrintToServer("Successfully parsed %s", confil);
			sharedCount = g_ModelName.Length;
			PrintToServer("Loaded %i shared models.", sharedCount);
		}
		delete fl;
		
		if (!FindConfigFileForMap(g_Mapname, confil, sizeof(confil)))
		{
			LogMessage("[PH] Config file for map %s not found. Disabling plugin.", g_Mapname);
			g_Enabled = false;
			return;
		}
		
		fl = CreateKeyValues("prophuntmapconfig");
		
		if(!fl.ImportFromFile(confil))
		{
			LogMessage("[PH] Config file for map %s at %s could not be opened. Disabling plugin.", g_Mapname, confil);
			delete fl;
			g_Enabled = false;
			return;
		}
		else
		{
			PrintToServer("Successfully loaded %s", confil);
			fl.GotoFirstSubKey();
			fl.JumpToKey("Props", false);
			fl.GotoFirstSubKey();
			do
			{
				fl.GetSectionName(buffer, sizeof(buffer));
				if (!FileExists(buffer, true))
				{
					LogError("%s: Prop does not exist: %s", confil, buffer);
					continue;
				}
				g_ModelName.PushString(buffer);
				g_PropMenu.AddItem(buffer, buffer);
				fl.GetString("offset", offset, sizeof(offset), "0 0 0");
				g_ModelOffset.PushString(offset);
				fl.GetString("rotation", rotation, sizeof(rotation), "0 0 0");
				g_ModelRotation.PushString(rotation);
				g_ModelSkin.Push(fl.GetNum("skin", 0));
			}
			while (fl.GotoNextKey());
			fl.Rewind();
			fl.JumpToKey("Settings", false);
			
			g_Doors = view_as<bool>(fl.GetNum("doors", 0));
			g_Relay = view_as<bool>(fl.GetNum("relay", 0));
			g_Freeze = view_as<bool>(fl.GetNum("freeze", 1));
			g_RoundTime = fl.GetNum("round", 175);
			g_Setup = fl.GetNum("setup", 30);
			
			PrintToServer("Successfully parsed %s", confil);
			PrintToServer("Loaded %i models, doors: %i, relay: %i, freeze: %i, round time: %i, setup: %i.", g_ModelName.Length-sharedCount, g_Doors ? 1:0, g_Relay ? 1:0, g_Freeze ? 1:0, g_RoundTime, g_Setup);
		}
		delete fl;
		
		char model[100];
		
		for(int i = 0; i < g_ModelName.Length; i++)
		{
			g_ModelName.GetString(i, model, sizeof(model));
			if(PrecacheModel(model, true) == 0)
			{
				g_ModelName.Erase(i);
			}
		}
		
		PrecacheModel(FLAMETHROWER, true);
		
		// workaround for CreateEntityByNsme
		g_MapStarted = true;
		
		loadGlobalConfig();
	}
	
	// workaround no win panel event - admin changes, rtv, etc.
	g_LastProp = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		g_LastPropDamageTime[client] = -1;
	}
	g_LastPropPlayer = 0;
	g_RoundOver = true;
	g_inSetup = false;
	//g_inPreRound = true;
	g_PlayerDied = false;
	g_flRoundStart = 0.0;
	
	// Clear the replacement weapon list
	for (int i = 1; i <= MaxClients; ++i)
	{
		for (int j = 0; j < sizeof(g_Replacements[]); ++j)
		{
			g_Replacements[i][j] = -1;
		}
		g_ReplacementCount[i] = 0;
	}
	
#if defined STATS
	g_MapChanging = false;
#endif

}

public void OnPluginEnd()
{
	PrintCenterTextAll("%t", "#TF_PH_PluginReload");
#if defined STATS
	Stats_Uninit();
#endif
	
	ResetCVars();
	if (g_SteamTools)
	{
		Steam_SetGameDescription("Team Fortress");
	}
	else
	if (g_SteamWorks)
	{
		SteamWorks_SetGameDescription("Team Fortress");
	}
#if defined OIMM
	if (g_OptinMultiMod)
	{
		OptInMultiMod_Unregister("prophunt");
	}
#endif
}

public Action TakeDamageHook(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!g_Enabled)
	{
		return Plugin_Continue;
	}
	
	if(victim > 0 && attacker > 0 && victim <= MaxClients && attacker <= MaxClients && IsClientInGame(victim) && IsClientInGame(attacker))
	{
		if (IsPlayerAlive(victim) && GetClientTeam(victim) == TEAM_PROP && GetClientTeam(attacker) == TEAM_HUNTER && !g_Hit[victim])
		{
			float pos[3];
			GetClientAbsOrigin(victim, pos);
			PH_EmitSoundToClient(victim, "PropFound", _, SNDCHAN_WEAPON, _, _, 0.8, _, victim, pos);
			PH_EmitSoundToClient(attacker, "PropFound", _, SNDCHAN_WEAPON, _, _, 0.8, _, victim, pos);
			g_Hit[victim] = true;
		}
		else if (g_LastProp && IsPlayerAlive(attacker) && GetClientTeam(victim) == TEAM_HUNTER && GetClientTeam(attacker) == TEAM_PROP)
		{
			g_LastPropDamageTime[victim] = GetTime();
		}
	}
	
	if(weapon > MaxClients && IsValidEntity(weapon))
	{
		char weaponIndex[10];
		IntToString(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"), weaponIndex, sizeof(weaponIndex));
		
		float multiplier;
		if (g_hWeaponNerfs.GetValue(weaponIndex, multiplier))
		{
			damage *= multiplier;
			return Plugin_Changed;
		}
	}
	
	//block prop drowning
	if(damagetype & DMG_DROWN && victim > 0 && victim <= MaxClients && IsClientInGame(victim) && GetClientTeam(victim) == TEAM_PROP && attacker == 0)
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	// block fall damage if set
	if(g_PHPreventFallDamage.BoolValue && damagetype & DMG_FALL && victim > 0 && victim <= MaxClients && IsClientInGame(victim) && attacker == 0)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock void RemovePropModel (int client){
	if(IsClientInGame(client) && IsPlayerAlive(client) && IsValidEntity(client))
	{
		SetVariantString("0 0 0");
		AcceptEntityInput(client, "SetCustomModelOffset");

		AcceptEntityInput(client, "ClearCustomModelRotation");
		
		SetVariantString("");
		AcceptEntityInput(client, "SetCustomModel");
		
		SetEntProp(client, Prop_Send, "m_bForcedSkin", false);
		SetEntProp(client, Prop_Send, "m_nForcedSkin", 0);
	}
}

#if defined STATS
public void OnClientDisconnect(int client)
{
	OCD(client);
}
#endif

public void OnClientDisconnect_Post(int client)
{
	ResetPlayer(client);
#if defined STATS
	OCD_Post(client);
#endif
}

stock void SwitchView (int target, bool observer, bool viewmodel){
	g_First[target] = !observer;
	
	SetVariantInt(observer ? 1 : 0);
	AcceptEntityInput(target, "SetForcedTauntCam");

	SetVariantInt(observer ? 1 : 0);
	AcceptEntityInput(target, "SetCustomModelVisibletoSelf");
}

public Action Command_jointeam(int client, int args)
{
	char argstr[16];
	GetCmdArgString(argstr, sizeof(argstr));
	if(StrEqual(argstr, "spectatearena"))
	{
		g_Spec[client] = true;
	}
	else
	{
		g_Spec[client] = false;
	}
	return Plugin_Continue;
}

public Action Command_ReloadConfig(int client, int args)
{
	loadGlobalConfig();
	CReplyToCommand(client, "PropHunt Config reloaded");
	return Plugin_Handled;
}

public Action Command_propmenu(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client <= 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	if(g_PHPropMenu.IntValue >= 0)
	{
		if(GetClientTeam(client) == TEAM_PROP && IsPlayerAlive(client))
		{
			if (GetCmdArgs() == 1)
			{
				if (CanPropChange(client))
				{
					char model[PLATFORM_MAX_PATH];
					GetCmdArg(1, model, sizeof(model));
					
					if (!FileExists(model, true))
					{
						CReplyToCommand(client, "%t", "#TF_PH_PropModelNotFound");
						return Plugin_Handled;
					}
					
					bool restrict = true;
					
					restrict = g_PHPropMenuRestrict.BoolValue;
					if (restrict)
					{
						bool found = false;
						
						int count = GetMenuItemCount(g_PropMenu);
						for (int i = 0; i < count; i++)
						{
							char otherModel[PLATFORM_MAX_PATH];
							g_PropMenu.GetItem(i, otherModel, sizeof(otherModel));
							if (strcmp(model, otherModel, false) == 0)
							{
								found = true;
								break;
							}
						}
						
						if (!found)
						{
							CReplyToCommand(client, "%t", "#TF_PH_PropMenuNotFound");
							return Plugin_Handled;
						}
					}
					g_RoundStartMessageSent[client] = false;
					strcopy(g_PlayerModel[client], sizeof(g_PlayerModel[]), model);
					RequestFrame(DoEquipProp, GetClientUserId(client));
				}
				else
				{
					CReplyToCommand(client, "%t", "#TF_PH_PropCantChange");
				}
			}
			else
			{
				if (GetClientMenu(client) == MenuSource_None)
				{
					DisplayMenu(g_PropMenu, client, MENU_TIME_FOREVER);
				}
			}
		}
		else
		{
			CReplyToCommand(client, "%t", "#TF_PH_PropMenuNotRedOrAlive");
		}
	}
	else
	{
		CReplyToCommand(client, "%t", "#TF_PH_PropMenuNoAccess");
	}
	return Plugin_Handled;
}

public Action Command_propreroll(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client <= 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	if(g_PHReroll.IntValue >= 0)
	{
		if(GetClientTeam(client) == TEAM_PROP && IsPlayerAlive(client))
		{
			if (!g_Rerolled[client])
			{
				if (CanPropChange(client))
				{
					g_Rerolled[client] = true;
					g_PlayerModel[client] = "";
					g_RoundStartMessageSent[client] = false;
					RequestFrame(DoEquipProp, GetClientUserId(client));
				}
				else
				{
					CReplyToCommand(client, "%t", "#TF_PH_PropCantChange");
				}
			}
			else
			{
				CReplyToCommand(client, "%t", "#TF_PH_PropRerollLimit");
			}
		}
		else
		{
			CReplyToCommand(client, "%t", "#TF_PH_PropRerollNotRedOrAlive");
		}
	}
	else
	{
		CReplyToCommand(client, "%t", "#TF_PH_PropRerollNoAccess");
	}
	return Plugin_Handled;
}

public int Handler_PropMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", "#TF_PH_PropMenuName", param1);
			
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}
		
		case MenuAction_Select:
		{
			if(IsClientInGame(param1))
			{
				if(g_PHPropMenu.IntValue == 1 || CheckCommandAccess(param1, "propmenu", ADMFLAG_KICK))
				{
					if(GetClientTeam(param1) == TEAM_PROP && IsPlayerAlive(param1))
					{
						if (CanPropChange(param1))
						{
							menu.GetItem(param2, g_PlayerModel[param1], sizeof(g_PlayerModel[]));
							g_RoundStartMessageSent[param1] = false;
							RequestFrame(DoEquipProp, GetClientUserId(param1));
						}
						else
						{
							CPrintToChat(param1, "%t", "#TF_PH_PropCantChange");
							int pos = menu.Selection;
							menu.DisplayAt(param1, pos, MENU_TIME_FOREVER);
						}
					}
					else
					{
						CPrintToChat(param1, "%t", "#TF_PH_PropMenuNotRedOrAlive");
					}
				}
				else
				{
					CPrintToChat(param1, "%t", "#TF_PH_PropMenuNoAccess");
				}
			}
		}
		
		case MenuAction_DisplayItem:
		{
			if (!g_PHPropMenuNames.BoolValue)
			{
				return 0;
			}
			
			char model[PLATFORM_MAX_PATH];
			menu.GetItem(param2, model, sizeof(model));
			
			char modelName[MAXMODELNAME];
			if (GetModelNameForClient(param1, model, modelName, sizeof(modelName)))
			{
				return RedrawMenuItem(modelName);
			}
		}
	}
	return 0;
}

bool CanPropChange(int client)
{
	if (!g_PHDamageBlocksPropChange.BoolValue)
	{
		return true;
	}
	
	if (TF2_IsPlayerInCondition(client, TFCond_OnFire) || TF2_IsPlayerInCondition(client, TFCond_Bleeding) || TF2_IsPlayerInCondition(client, TFCond_Jarated) || TF2_IsPlayerInCondition(client, TFCond_Milked))
	{
		return false;
	}
	return true;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitch);
	
	if (!g_Enabled)
		return;
	
	if (!IsFakeClient(client))
	{
		SendConVarValue(client, g_hArenaRoundTime, "600");
	}
	ResetPlayer(client);
}

public void ResetPlayer(int client)
{
	g_Spawned[client] = false;
	g_Charge[client] = false;
	g_AllowedSpawn[client] = false;
	g_Hit[client] = false;
	g_Attacking[client] = false;
	g_RotLocked[client] = false;
	g_Spec[client] = false;
	g_TouchingCP[client] = false;
	g_First[client] = false;
	g_PlayerModel[client] = "";
	g_SetClass[client] = false;
	g_Rerolled[client] = false;
	g_CurrentlyFlaming[client] = false;
	g_FlameCount[client] = 0;
	g_LastPropDamageTime[client] = -1;
	g_RoundStartMessageSent[client] = false;
}

public Action Command_respawn(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client < 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	TF2_RespawnPlayer(client);
	return Plugin_Handled;
}

public Action Command_internet(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	//char name[PLATFORM_MAX_PATH];
	for(int i = 0; i < 3; i++)
	{
		PH_EmitSoundToAll("Internet", _, _, SNDLEVEL_AIRCRAFT);
	}
	//GetClientName(client, name, sizeof(name));
	return Plugin_Handled;
}

void PH_EmitSoundToAll(const char[] soundid, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, float volume = SNDVOL_NORMAL,
	int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true, float soundtime = 0.0)
{
	char sample[128];
	
	if(g_BroadcastSounds.GetString(soundid, sample, sizeof(sample)))
	{
		if (EntRefToEntIndex(g_GameRulesProxy) != INVALID_ENT_REFERENCE)
		{
			SetVariantString(sample);
			AcceptEntityInput(g_GameRulesProxy, "PlayVO");
		}
	}
	else if(g_Sounds.GetString(soundid, sample, sizeof(sample)))
	{
		EmitSoundToAll(sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
	}
}

stock void PH_EmitSoundToTeam(TFTeam team, const char[] soundid, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS, 
	float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true,
	float soundtime = 0.0)
{
	char sample[128];
	
	if(g_BroadcastSounds.GetString(soundid, sample, sizeof(sample)))
	{
		if (EntRefToEntIndex(g_GameRulesProxy) != INVALID_ENT_REFERENCE)
		{
			SetVariantString(sample);
			if (team == TFTeam_Red)
			{
				AcceptEntityInput(g_GameRulesProxy, "PlayVORed");
			}
			else if (team == TFTeam_Blue)
			{
				AcceptEntityInput(g_GameRulesProxy, "PlayVOBlue");
			}
			else if (team <= 0)
			{
				AcceptEntityInput(g_GameRulesProxy, "PlayVO");
			}
		}
	}
	else if(g_Sounds.GetString(soundid, sample, sizeof(sample)))
	{
		int count = 0;
		int clients = new int[MaxClients];
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == team)
			{
				clients[count++] = client;
			}
		}
		
		EmitSound(clients, count, sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
	}
	
}


void PH_EmitSoundToClient(int client, const char[] soundid, int entity = SOUND_FROM_PLAYER, int channel = SNDCHAN_AUTO, int level = SNDLEVEL_NORMAL, int flags = SND_NOFLAGS,
	float volume = SNDVOL_NORMAL, int pitch = SNDPITCH_NORMAL, int speakerentity = -1, const float origin[3] = NULL_VECTOR, const float dir[3] = NULL_VECTOR, bool updatePos = true,
	float soundtime = 0.0)
{
	char sample[128];
	
	bool emitted = false;

	if(g_BroadcastSounds.GetString(soundid, sample, sizeof(sample)))
	{
		emitted = EmitGameSoundToClient(client, sample, entity, flags, speakerentity, origin, dir, updatePos, soundtime);
	}

	if(!emitted && g_Sounds.GetString(soundid, sample, sizeof(sample)))
	{
		EmitSoundToClient(client, sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
	}
}

public Action Command_switch(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client < 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	g_AllowedSpawn[client] = true;
	ChangeClientTeam(client, TEAM_PROP);
	TF2_RespawnPlayer(client);
	CreateTimer(0.5, Timer_Move, GetClientUserId(client));
	return Plugin_Handled;
}

public Action Command_pyro(int client, int args)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	if (client < 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	g_PlayerModel[client] = "";
	g_AllowedSpawn[client] = true;
	ChangeClientTeam(client, TEAM_HUNTER);
	TF2_RespawnPlayer(client);
	CreateTimer(0.5, Timer_Move, GetClientUserId(client));
	CreateTimer(0.8, Timer_Unfreeze, GetClientUserId(client));
	return Plugin_Handled;
}
stock int PlayersAlive (){
	int alive = 0;
	for(int i=1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		alive++;
	}
	return alive;
}

stock void ChangeClientTeamAlive (int client, int team)
{
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, team);
	SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

stock int GetRandomPlayer (int team)
{
	int client, totalclients;

	for(client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			totalclients++;
		}
	}

	int clientarray[totalclients], i;
	for(client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			clientarray[i] = client;
			i++;
		}
	}

	do
	{
		client = clientarray[GetRandomInt(0, totalclients-1)];
	}
	while( !(IsClientInGame(client) && GetClientTeam(client) == team) );
	return client;
}

stock bool IsPropHuntMap()
{
	return ValidateMap(g_Mapname);
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if(!g_Enabled || g_RoundOver)
		return Plugin_Continue;
	
	if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_HUNTER && IsValidEntity(weapon))
	{
		if(strcmp(weaponname, "tf_weapon_flamethrower") == 0)
		{
			g_CurrentlyFlaming[client] = true;
			g_FlameCount[client] = 0;
		}
		else
			DoSelfDamage(client, weapon);
		
		result = false;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!g_Enabled || g_RoundOver || !g_CurrentlyFlaming[client])
	{
		return Plugin_Continue;
	}
	
	if (buttons & IN_ATTACK != IN_ATTACK)
	{
		g_CurrentlyFlaming[client] = false;
		g_FlameCount[client] = 0;
		return Plugin_Continue;
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (!g_Enabled || g_RoundOver)
	{
		return;
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !g_CurrentlyFlaming[client] || GetClientTeam(client) != TEAM_HUNTER || !IsPlayerAlive(client) || g_FlameCount[client]++ % FLY_COUNT != 0)
		{
			continue;
		}
		
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if (IsValidEntity(weapon))
		{
			DoSelfDamage(client, weapon);
			AddVelocity(client, 1.0);
		}
	}
}

public void WeaponSwitch(int client, int weapon)
{
	if (!g_Enabled || g_RoundOver || !g_CurrentlyFlaming[client])
	{
		return;
	}
	
	char weaponname[64];
	GetEntityClassname(weapon, weaponname, sizeof(weaponname));
	
	if(strcmp(weaponname, "tf_weapon_flamethrower") != 0)
	{
		g_CurrentlyFlaming[client] = false;
		g_FlameCount[client] = 0;
	}
}

stock void DoSelfDamage(int client, int weapon)
{
	float damage;
	int attacker = client;
	
	char weaponIndex[10];
	IntToString(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"), weaponIndex, sizeof(weaponIndex));
	
	char weaponname[64];
	GetEntityClassname(weapon, weaponname, sizeof(weaponname));
	
	if (!g_hWeaponSelfDamage.GetValue(weaponIndex, damage))
	{
		damage = 10.0;
	}
	
	if (g_LastProp && strcmp(weaponname, "tf_weapon_flamethrower") == 0 && g_LastPropPlayer > 0 && IsClientInGame(g_LastPropPlayer) && IsPlayerAlive(g_LastPropPlayer) && 
		g_LastPropDamageTime[client] > -1 && g_LastPropDamageTime[client] + PROP_DAMAGE_TIME >= GetTime() && damage >= GetEntProp(client, Prop_Send, "m_iHealth"))
	{
		attacker = g_LastPropPlayer;
		//weapon = 0;
	}
	
	// Attacker shouldn't be the weapon, it should be the player
	// weapon is no longer used as it caused bugs in bleed damage
	SDKHooks_TakeDamage(client, client, attacker, damage, DMG_PREVENT_PHYSICS_FORCE);
}

stock void AddVelocity(int client, float speed){
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

	// fucking win
	if(velocity[0] < 200 && velocity[0] > -200)
	velocity[0] *= (1.08 * speed);
	if(velocity[1] < 200 && velocity[1] > -200)
	velocity[1] *= (1.08 * speed);
	if(velocity[2] > 0 && velocity[2] < 400)
	velocity[2] = velocity[2] * 1.15 * speed;

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

public Action SetTransmitHook(int entity, int client)
{
	if(g_First[client] && client == entity)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void PreThinkHook(int client)
{
	if (!g_Enabled)
		return;
	
	if(IsClientInGame(client))
	{

		if(IsPlayerAlive(client))
		{
			if(!(TF2_IsPlayerInCondition(client, TFCond_Slowed) || TF2_IsPlayerInCondition(client, TFCond_Zoomed) || 
			TF2_IsPlayerInCondition(client, TFCond_Bonked) || TF2_IsPlayerInCondition(client, TFCond_Dazed) || 
			TF2_IsPlayerInCondition(client, TFCond_Charging) || TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly)))
			{
				ResetSpeed(client);
			}
			
			int buttons = GetClientButtons(client);
			if((buttons & IN_ATTACK) == IN_ATTACK && GetClientTeam(client) == TEAM_HUNTER)
			{
				g_Attacking[client] = true;
			}
			else
			{
				g_Attacking[client] = false;
			}

			if(GetClientTeam(client) == TEAM_PROP)
			{
				// tl;dr - (LMB and not crouching OR any movement key while locked) AND not holding key
				if(((((buttons & IN_ATTACK) == IN_ATTACK && (buttons & IN_DUCK) != IN_DUCK) ||
								((buttons & IN_FORWARD) == IN_FORWARD || (buttons & IN_MOVELEFT) == IN_MOVELEFT || (buttons & IN_MOVERIGHT) == IN_MOVERIGHT ||
									(buttons & IN_BACK) == IN_BACK || (buttons & IN_JUMP) == IN_JUMP) && g_RotLocked[client])) && !g_HoldingLMB[client]
						)
				{
					g_HoldingLMB[client] = true;
					if(GetPlayerWeaponSlot(client, 0) == -1)
					{

						if(!g_RotLocked[client])
						{
							float velocity[3];
							GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
							//GetEntDataVector(client, g_iVelocity, velocity);
							// if the client is moving, don't allow them to lock in place
							if(velocity[0] > -5 && velocity[1] > -5 && velocity[2] > -5 && velocity[0] < 5 && velocity[1] < 5 && velocity[2] < 5)
							{
								SetVariantInt(0);
								AcceptEntityInput(client, "SetCustomModelRotates");
								g_RotLocked[client] = true;
#if defined LOCKSOUND
								PH_EmitSoundToClient(client, "LockSound", _, _, _, _, LOCKVOL);
#endif
							}

						}
						else
						if(g_RotLocked[client])
						{
							SetVariantInt(1);
							AcceptEntityInput(client, "SetCustomModelRotates");
#if defined LOCKSOUND
							PH_EmitSoundToClient(client, "UnlockSound", _, _, _, _, LOCKVOL);
#endif
							g_RotLocked[client] = false;
						}
					}
				}
				else if((buttons & IN_ATTACK) != IN_ATTACK)
				{
					g_HoldingLMB[client] = false;
				}

				if((buttons & IN_ATTACK2) == IN_ATTACK2 && !g_HoldingRMB[client])
				{
					g_HoldingRMB[client] = true;
					if(g_First[client])
					{
						PrintHintText(client, "Third Person mode selected");
						SwitchView(client, true, false);
					}
					else
					{
						PrintHintText(client, "First Person mode selected");
						SwitchView(client, false, false);
					}

				}
				else
				if((buttons & IN_ATTACK2) != IN_ATTACK2)
				{
					g_HoldingRMB[client] = false;
				}
#if defined CHARGE
				if((buttons & IN_RELOAD) == IN_RELOAD)
				{
					if(!g_Charge[client])
					{
						g_Charge[client] = true;
						//SetEntData(client, g_offsCollisionGroup, COLLISION_GROUP_DEBRIS_TRIGGER, _, true);
						SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
						TF2_SetPlayerClass(client, TFClass_DemoMan, false);
						TF2_AddCondition(client, TFCond_Charging, 2.5);
						CreateTimer(2.5, Timer_Charge, GetClientUserId(client));
					}
				}
#endif
			}
			else
			if(GetClientTeam(client) == TEAM_HUNTER && TF2_GetPlayerClass(client) == TFClass_Pyro)
			{
				int shotgun = GetPlayerWeaponSlot(client, 1);
				if(IsValidEntity(shotgun))
				{
					int index = GetEntProp(shotgun, Prop_Send, "m_iItemDefinitionIndex");
					if (index == WEP_SHOTGUNPYRO || index == WEP_SHOTGUN_UNIQUE)
					{
						int ammoOffset = GetEntProp(shotgun, Prop_Send, "m_iPrimaryAmmoType");
						int clip = GetEntProp(shotgun, Prop_Send, "m_iClip1");
						SetEntProp(client, Prop_Send, "m_iAmmo", SHOTGUN_MAX_AMMO - clip, _, ammoOffset);
						if (clip > SHOTGUN_MAX_AMMO)
						{
							SetEntProp(shotgun, Prop_Send, "m_iClip1", SHOTGUN_MAX_AMMO);
						}
					}
				}
				
			}

		} // alive
	} // in game
}

public int GetClassCount(TFClassType class, int team) 
{
	int classCount;
	for(int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team && TF2_GetPlayerClass(client) == class)
		{
			classCount++;
		}
	}
	return classCount;
}

public Action Command_motd(int client, int args)
{
	if (client <= 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	if(IsClientInGame(client))
	{
		ShowMOTDPanel(client, "PropHunt Stats", "http://www.gamingmasters.org/prophunt/index.php", MOTDPANEL_TYPE_URL);
	}
	return Plugin_Handled;
}

public Action Command_config(int client, int args)
{
	if (client == 0)
	{
		DisplayConfigToConsole(client);
	}
	else
	{
		if (GetClientMenu(client) == MenuSource_None)
		{
			DisplayMenu(g_ConfigMenu, client, MENU_TIME_FOREVER);
		}
	}
		
	return Plugin_Handled;
}

void DisplayConfigToConsole(int client)
{
	char propMenuStatus[18];
	char propRerollStatus[18];
	char preventFallDamage[4];
	char propChangeRestrict[4];
	char airblast[4];
	char propMenuRestrict[4];
	int propMenu = g_PHPropMenu.IntValue;
	int propReroll = g_PHReroll.IntValue;
	
	if (g_PHAirblast.BoolValue)
	{
		airblast = "On";
	}
	else
	{
		airblast = "Off";
	}
	
	switch (propMenu)
	{
		case -1:
		{
			propMenuStatus = "Off";
		}
		
		case 0:
		{
			propMenuStatus = "#TF_PH_Restricted";
		}
		
		case 1:
		{
			propMenuStatus = "On";
		}
	}
	
	if (g_PHPropMenuRestrict.BoolValue)
	{
		propMenuRestrict = "On";
	}
	else
	{
		propMenuRestrict = "Off";
	}
	
	if (g_PHDamageBlocksPropChange.BoolValue)
	{
		propChangeRestrict = "On";
	}
	else
	{
		propChangeRestrict = "Off";
	}
	
	switch (propReroll)
	{
		case -1:
		{
			propRerollStatus = "Off";
		}
		
		case 0:
		{
			propRerollStatus = "#TF_PH_Restricted";
		}
		
		case 1:
		{
			propRerollStatus = "On";
		}
	}
	
	if (g_PHPreventFallDamage.BoolValue)
	{
		preventFallDamage = "On";
	}
	else
	{
		preventFallDamage = "Off";
	}
	
	CReplyToCommand(client, "%t", "#TF_PH_ConfigName");
	CReplyToCommand(client, "---------------------");
	CReplyToCommand(client, "%t", "#TF_PH_ConfigVersion", PL_VERSION);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigAirblast", airblast);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigPropMenu", propMenuStatus);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigPropMenuRestrict", propMenuRestrict);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigPropChange", propChangeRestrict);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigPropReroll", propRerollStatus);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigPreventFallDamage", preventFallDamage);
	CReplyToCommand(client, "%t", "#TF_PH_ConfigSetupTime", g_PHSetupLength.IntValue);
#if defined STATS
	CReplyToCommand(client, "%t", "#TF_PH_ConfigStats");
#endif
}

public int Handler_ConfigMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigName", param1);
			
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}
		
		case MenuAction_Select:
		{
			// We really just close the menu when they select something
		}
		
		case MenuAction_DisplayItem:
		{
			char infoBuf[64];
			menu.GetItem(param2, infoBuf, sizeof(infoBuf));
			char buffer[255];
			
			if (StrEqual(infoBuf, "#version"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigVersion", param1, PL_VERSION);
			}
			else
			if (StrEqual(infoBuf, "#airblast"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigAirblast", param1, g_PHAirblast.BoolValue ? "On" : "Off");
			}
			else
			if (StrEqual(infoBuf, "#propmenu"))
			{
				int propMenu = g_PHPropMenu.IntValue;
				
				char propMenuStatus[25];
				
				switch (propMenu)
				{
					case -1:
					{
						propMenuStatus = "Off";
					}
					
					case 0:
					{
						if (CheckCommandAccess(param1, "propmenu", ADMFLAG_KICK))
						{
							propMenuStatus = "#TF_PH_RestrictedAllowed";
						}
						else
						{
							propMenuStatus = "#TF_PH_RestrictedDenied";
						}
					}
					
					case 1:
					{
						propMenuStatus = "On";
					}
				}
				
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigPropMenu", param1, propMenuStatus);
			}
			else
			if (StrEqual(infoBuf, "#proprestrict"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigPropMenuRestrict", param1, g_PHPropMenuRestrict.BoolValue ? "On" : "Off");
			}
			else
			if (StrEqual(infoBuf, "#propdamage"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigPropChange", param1, g_PHDamageBlocksPropChange.BoolValue ? "On" : "Off");
			}
			else
			if (StrEqual(infoBuf, "#propreroll"))
			{
				int propReroll = g_PHReroll.IntValue;
				
				char propRerollStatus[25];
				
				switch (propReroll)
				{
					case -1:
					{
						propRerollStatus = "Off";
					}
					
					case 0:
					{
						if (CheckCommandAccess(param1, "propreroll", ADMFLAG_KICK))
						{
							propRerollStatus = "#TF_PH_RestrictedAllowed";
						}
						else
						{
							propRerollStatus = "#TF_PH_RestrictedDenied";
						}
					}
					
					case 1:
					{
						propRerollStatus = "On";
					}
				}
				
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigPropReroll", param1, propRerollStatus);
			}
			else
			if (StrEqual(infoBuf, "#preventfalldamage"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigPreventFallDamage", param1, g_PHPreventFallDamage.BoolValue ? "On" : "Off");
			}
			else
			if (StrEqual(infoBuf, "#setuptime"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigSetupTime", param1, g_PHSetupLength.IntValue);
			}
#if defined STATS
			else
			if (StrEqual(infoBuf, "#stats"))
			{
				Format(buffer, sizeof(buffer), "%T", "#TF_PH_ConfigStats", param1);
			}
#endif
			
			return RedrawMenuItem(buffer);
		}
	}
	return 0;
}

stock void SetAlpha(int target, int alpha) {
	SetWeaponsAlpha(target,alpha);
	SetEntityRenderMode(target, RENDER_TRANSCOLOR);
	SetEntityRenderColor(target, 255, 255, 255, alpha);
}

stock void SetWeaponsAlpha(int target, int alpha) {
	if(IsPlayerAlive(target))
	{
		// TF2 only supports 1 weapon per slot, so save time and just check all 6 slots.
		// Engy is the only class with 6 items (3 weapons, 2 tools, and an invisible builder)
		for(int i = 0; i <= 5; ++i)
		{
			int weapon = GetPlayerWeaponSlot(target, i);
			
			SetItemAlpha(weapon, alpha);
		}
	}
}

stock void SetItemAlpha(int item, int alpha)
{
	if(item > -1 && IsValidEdict(item))
	{
		SetEntityRenderMode(item, RENDER_TRANSCOLOR);
		SetEntityRenderColor(item, 255, 255, 255, alpha);
		
		char classname[65];
		GetEntityClassname(item, classname, sizeof(classname));
		
		// If it's a weapon, lets adjust the alpha on its extra wearable and its viewmodel too
		if (strncmp(classname, "tf_weapon_", 10) == 0)
		{
			SetItemAlpha(GetEntPropEnt(item, Prop_Send, "m_hExtraWearable"), alpha);
			SetItemAlpha(GetEntPropEnt(item, Prop_Send, "m_hExtraWearableViewModel"), alpha);
		}
	}
}

public void Speedup(int client)
{
	TFClassType clientClass = TF2_GetPlayerClass(client);
	
	float clientSpeed = g_currentSpeed[client] + g_classSpeeds[clientClass][2];
	
	if(clientSpeed < g_classSpeeds[clientClass][0])
	{
		clientSpeed = g_classSpeeds[clientClass][0];
	}
	else if(clientSpeed > g_classSpeeds[clientClass][1])
	{
		clientSpeed = g_classSpeeds[clientClass][1];
	}
	
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", clientSpeed);
	
	g_currentSpeed[client]  = clientSpeed;
}

void ResetSpeed(int client)
{	
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", g_currentSpeed[client]);
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data;
}

public Action Event_teamplay_broadcast_audio(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Enabled)
		return Plugin_Continue;
	
	char sound[64];
	event.GetString("sound", sound, sizeof(sound));
	
	if (StrEqual(sound, "Announcer.AM_RoundStartRandom", false))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void Event_player_team(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(event.GetInt("team") > 1)
	{
		g_Spec[client] = false;
	}
	g_RoundStartMessageSent[client] = false;
}

public void Event_arena_win_panel(Event event, const char[] name, bool dontBroadcast)
{
	StopTimers();
#if defined LOG
	LogMessage("[PH] round end");
#endif

	g_RoundOver = true;
	//g_inPreRound = true;
	g_LastProp = false;
	
	if (!g_Enabled)
		return;

#if defined STATS
	int winner = event.GetInt("winning_team");

	DbRound(winner);
#endif

	if (Internal_ShouldSwitchTeams())
	{
		/*
		 * Check if we need this or if classic works
		  
		int redScore;
		int bluScore;
		
		// This block is necessary because _score is always 0 for the losing team
		// even though scores aren't cleared when tf_arena_use_queue is set to 0
		if (winner == TEAM_RED)
		{
			redScore = event.GetInt("red_score");
			bluScore = event.GetInt("blue_score_prev");
		}
		else
		if (winner == TEAM_BLUE)
		{
			redScore = event.GetInt("red_score_prev");
			bluScore = event.GetInt("blue_score");
		}
		else
		{
			// Neither team wins, they both keep their previous scores
			redScore = event.GetInt("red_score_prev");
			bluScore = event.GetInt("blue_score_prev");
		}
		SwitchTeamScores(redScore, bluScore);

		*/

#if defined SWITCH_TEAMS
		// This is OK as arena_win_panel is fired *after* SetWinningTeam is called.
		SetSwitchTeams(true);
#else
		CreateTimer(g_hBonusRoundTime.FloatValue - TEAM_CHANGE_TIME, Timer_ChangeTeam, _, TIMER_FLAG_NO_MAPCHANGE);
#endif
	}
	
	g_hTeamsUnbalanceLimit.IntValue = 0;

	for(int client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
#if defined STATS
			if(GetClientTeam(client) == winner)
			{
				AlterScore(client, 3, ScReason_TeamWin, 0);
			}
			else
			if(GetClientTeam(client) != _:TFTeam_Spectator)
			{
				AlterScore(client, -1, ScReason_TeamLose, 0);
			}
#endif
			// bit annoying when testing the plugin and/or maps on a listen server
			/*
			if(IsDedicatedServer())
			{
				team = GetClientTeam(client);
				if(team == TEAM_PROP || team == TEAM_HUNTER)
				{
					team = team == TEAM_PROP ? TEAM_HUNTER:TEAM_PROP;
					ChangeClientTeamAlive(client, team);
				}
			}
			*/
		}
		//ResetPlayer(client); // Players are now reset on round start instead of round end
	}

	g_hTeamsUnbalanceLimit.Flags = g_hTeamsUnbalanceLimit.Flags & ~FCVAR_NOTIFY;
	g_hTeamsUnbalanceLimit.IntValue = UNBALANCE_LIMIT;
}

public Action Timer_ChangeTeam(Handle timer)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client))
		{
			continue;
		}
		
		if (GetClientTeam(client) == TEAM_HUNTER)
		{
			ChangeClientTeamAlive(client, TEAM_PROP);
		}
		else
		if (GetClientTeam(client) == TEAM_PROP)
		{
			RemovePropModel(client);
			ChangeClientTeamAlive(client, TEAM_HUNTER);
		}
		
	}
	return Plugin_Continue;
}

public void Event_post_inventory_application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_ReplacementCount[client] > 0)
	{
	
		for (int i = 0; i < g_ReplacementCount[client]; ++i)
		{
			// DON'T require FORCE_GENERATION here, since they could pass back tf_weapon_shotgun 
			Handle weapon = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES);
			
			char defIndex[7];
			IntToString(g_Replacements[client][i], defIndex, sizeof(defIndex));
			
			char replacement[140];
			if (!g_hWeaponReplacements.GetString(defIndex, replacement, sizeof(replacement)))
			{
				continue;
			}
			
			char pieces[5][128];
			
			ExplodeString(replacement, ":", pieces, sizeof(pieces), sizeof(pieces[]));

			TrimString(pieces[Item_Classname]);
			TrimString(pieces[Item_Index]);
			TrimString(pieces[Item_Quality]);
			TrimString(pieces[Item_Level]);
			TrimString(pieces[Item_Attributes]);
			
			int index = StringToInt(pieces[Item_Index]);
			int quality = StringToInt(pieces[Item_Quality]);
			int level = StringToInt(pieces[Item_Level]);
			TF2Items_SetClassname(weapon, pieces[Item_Classname]);
			TF2Items_SetItemIndex(weapon, index);
			TF2Items_SetQuality(weapon, quality);
			TF2Items_SetLevel(weapon, level);
			
			int attribCount = 0;
			if (strlen(pieces[Item_Attributes]) > 0)
			{
				char newAttribs[32][6];
				int count = ExplodeString(pieces[Item_Attributes], ";", newAttribs, sizeof(newAttribs), sizeof(newAttribs[]));
				if (count % 2 > 0)
				{
					LogError("Error parsing replacement attributes for item definition index %d", g_Replacements[client][i]);
					return;
				}
				
				for (int j = 0; j < count && attribCount < 16; j += 2)
				{
					TrimString(newAttribs[i]);
					TrimString(newAttribs[i+1]);
					int attrib = StringToInt(newAttribs[i]);
					float value = StringToFloat(newAttribs[i+1]);
					TF2Items_SetAttribute(weapon, attribCount++, attrib, value);
				}
			}
			
			TF2Items_SetNumAttributes(weapon, attribCount);
			
			int item = TF2Items_GiveNamedItem(client, weapon);
			EquipPlayerWeapon(client, item);
			g_Replacements[client][i] = -1;
			delete weapon;
		}
		
		g_ReplacementCount[client] = 0;
		// Now that we're adjusting weapons, this needs to happen to fix max ammo counts
		//TF2_RegeneratePlayer(client);
	}
}

public Action Event_teamplay_round_start_pre(Event event, const char[] name, bool dontBroadcast)
{
	switch (g_RoundChange)
	{
		case RoundChange_Enable:
		{
			g_Enabled = true;
			SetCVars();
			
			UpdateGameDescription();
			g_RoundChange = RoundChange_NoChange;
			g_RoundCurrent = 0;
			
			Internal_AddServerTag();
		}
		
		case RoundChange_Disable:
		{
			g_Enabled = false;
			ResetCVars();
			
			UpdateGameDescription();
			g_RoundChange = RoundChange_NoChange;			

			Internal_RemoveServerTag();
		}
	}
	
	return Plugin_Continue;
}

public void Event_teamplay_round_start(Event event, const char[] name, bool dontBroadcast)
{
	if (HasSwitchedTeams())
	{
		SwitchTeamScoresClassic();
	}
	
	StopTimers();
	
	if (!g_Enabled)
		return;

	
	g_inPreRound = true;
	g_PlayerDied = false;
	g_flRoundStart = 0.0;
	
	// This is now in round start after an issue was reported with last prop not resetting in 3.0.2
	g_LastProp = false;
	g_LastPropPlayer = 0;
	g_RoundOver = true;

	for (int client = 1; client <= MaxClients; client++)
	{
		ResetPlayer(client);	
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			// For some reason, this has to be set every round or the player GUI messes up
			g_hArenaRoundTime.ReplicateToClient(client, "600");
		}
	}
	// Delay freeze by a frame
	RequestFrame(Delay_teamplay_round_start);
	
	// Arena maps should have a team_control_point_master already, but just in case...
	int ent = FindEntityByClassname(-1, "team_control_point_master");
	if (ent == -1)
	{
		ent = CreateEntityByName("team_control_point_master");
		DispatchKeyValue(ent, "targetname", "master_control_point");
		DispatchKeyValue(ent, "StartDisabled", "0");
		DispatchSpawn(ent);
	}

	//GameMode Explanation
	char message[256];

	// Not sure this has to be done every round, but we'll keep it here just in case.
	
	//BLU
	Format(message, sizeof(message), "%T", "#TF_PH_BluHelp", LANG_SERVER);
	SetVariantString(message);
	AcceptEntityInput(g_GameRulesProxy, "SetBlueTeamGoalString");
	SetVariantString("2");
	AcceptEntityInput(g_GameRulesProxy, "SetBlueTeamRole");

	//RED
	Format(message, sizeof(message), "%T", "#TF_PH_RedHelp", LANG_SERVER);
	SetVariantString(message);
	AcceptEntityInput(g_GameRulesProxy, "SetRedTeamGoalString");
	SetVariantString("1");
	AcceptEntityInput(g_GameRulesProxy, "SetRedTeamRole");
}

public void Delay_teamplay_round_start(any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsClientObserver(i))
		{
			SetEntityMoveType(i, MOVETYPE_NONE);
		}
	}
}

public void Event_teamplay_restart_round(Event event, const char[] name, bool dontBroadcast)
{
	// I'm not sure what needs to be here... does teamplay_round_start get called on round restart?
}

public void Event_arena_round_start(Event event, const char[] name, bool dontBroadcast)
{
#if defined LOG
	LogMessage("[PH] round start - %i", g_RoundOver );
#endif
	g_inPreRound = false;
	
	if (!g_Enabled)
		return;
	
	g_inSetup = true;
	
	g_RoundCurrent++;
	
	StartTimers(true);
	
	if(g_RoundOver)
	{
		// bl4nk mentions arena_round_start, but I think he meant teamplay_round_start
		RequestFrame(Delay_arena_round_start);
		
		CreateTimer(0.1, Timer_Info);

#if defined STATS
		g_StartTime = GetTime();
#endif
	}
}

public void Delay_arena_round_start(any data)
{
	for(int client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			if(GetClientTeam(client) == TEAM_PROP)
			{
				RequestFrame(DoEquipProp, GetClientUserId(client));
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
			else
			{
				RequestFrame(DoEquipHunter, GetClientUserId(client));
				if (!g_Freeze)
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
				}
			}
			g_currentSpeed[client] = g_classSpeeds[TF2_GetPlayerClass(client)][0]; // Reset to default speed.
		}
	}
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

public void Event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Enabled)
		return;
	
	int red = TEAM_PROP - 2;
	int blue = TEAM_HUNTER - 2;
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_currentSpeed[client] = g_classSpeeds[TF2_GetPlayerClass(client)][0]; // Reset to default speed.
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		// stupid glitch fix
		if(!g_RoundOver && !g_AllowedSpawn[client])
		{
#if defined LOG
			LogMessage("%N spawned outside of a round");
#endif
			ForcePlayerSuicide(client);
			return;
		}
		// Wipe their model in case they were a prop last round and lived
		RemovePropModel(client);
		SDKHook(client, SDKHook_OnTakeDamage, TakeDamageHook);
		SDKHook(client, SDKHook_PreThink, PreThinkHook);
#if defined LOG
		LogMessage("[PH] Player spawn %N", client);
#endif
		g_Hit[client] = false;

		int team = GetClientTeam(client);
		if(team == TEAM_HUNTER)
		{
			if (!g_RoundStartMessageSent[client])
			{
				CPrintToChat(client, "%t", "#TF_PH_WaitingPeriodStarted");
				g_RoundStartMessageSent[client] = true;
			}
#if defined SHINX

			TFClassType clientClass = TF2_GetPlayerClass(client);
			if (g_classLimits[blue][clientClass] != -1 && GetClassCount(clientClass, TEAM_HUNTER) > g_classLimits[blue][clientClass])
			{
				if(g_classLimits[blue][clientClass] == 0)
				{
					// By default, this fires when they're Scout
					//CPrintToChat(client, "%t", "#TF_PH_ClassBlocked");
				}
				else
				{
					CPrintToChat(client, "%t", "#TF_PH_ClassFull");
				}

				if (g_PreferredHunterClass[client] != TFClass_Unknown && g_PreferredHunterClass[client] != clientClass)
				{
					TF2_SetPlayerClass(client, g_PreferredHunterClass[client]);
				}
				else
				{
					TF2_SetPlayerClass(client, g_defaultClass[blue]);
				}
				
				TF2_RespawnPlayer(client);
				
				return;
			}
			
			// If we didn't just change their class, store it for later
			g_PreferredHunterClass[client] = clientClass;
#else
			if(TF2_GetPlayerClass(client) != g_defaultClass[blue])
			{
				TF2_SetPlayerClass(client, g_defaultClass[blue]);
				TF2_RespawnPlayer(client);
				return;
			}
#endif
			RequestFrame(DoEquipHunter, GetClientUserId(client));

		}
		else
		if(team == TEAM_PROP)
		{
			if(g_RoundOver)
			{
				SetEntityMoveType(client, MOVETYPE_NONE);
			}
			
			SetVariantString("");
			AcceptEntityInput(client, "DisableShadow");
			
			if(TF2_GetPlayerClass(client) != g_defaultClass[red])
			{
				TF2_SetPlayerClass(client, view_as<TFClassType>(g_defaultClass[red]), false, false);
				TF2_RespawnPlayer(client);
				return;	// This was missing prior to PHR 3.3.4
			}
			// CreateTimer(0.1, Timer_DoEquip, GetClientUserId(client));
			RequestFrame(DoEquipProp, GetClientUserId(client));
		}
		else
		{
			// Players are spawning on a non-player team?
			#if defined LOG
			LogMessage("%N spawned on a non-player team: %d, slaying...", client, team);
			#endif
			ForcePlayerSuicide(client);
		}
		
		if (g_inPreRound)
		{
			SetEntityMoveType(client, MOVETYPE_NONE);
		}
	}
}

public Action Event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Enabled || g_inPreRound)
		return Plugin_Continue;
	
	if (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		// This shouldn't fire since Spy is usually disabled, but just in case...
		return Plugin_Continue;
	}

	// This should be a separate event now, but we're leaving this in just in case
	if (GetEventInt(event, "weaponid") == TF_WEAPON_BAT_FISH && GetEventInt(event, "customkill") == TF_CUSTOM_FISH_KILL)
	{
		return Plugin_Continue;
	}
	//new bool:changed = false;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == 0)
		return Plugin_Continue;
		
	g_CurrentlyFlaming[client] = false;
	g_FlameCount[client] = 0;
	
	if(IsClientInGame(client) && GetClientTeam(client) == TEAM_PROP)
	{
#if defined LOG
		LogMessage("[PH] Player death %N", client);
#endif
		//RemovePropModel(client);

		CreateTimer(0.1, Timer_Ragdoll, GetClientUserId(client));

		SDKUnhook(client, SDKHook_OnTakeDamage, TakeDamageHook);
		SDKUnhook(client, SDKHook_PreThink, PreThinkHook);
	}

	if(g_inSetup && g_PHRespawnDuringSetup.BoolValue)
	{
		CreateTimer(0.1, Timer_Respawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
#if defined STATS
	char weapon[64];
	int attackerID = GetEventInt(event, "attacker");
	int assisterID = GetEventInt(event, "assister");
	int clientID = GetEventInt(event, "userid");
	int weaponid = GetEventInt(event, "weaponid");
	event.GetString("weapon", weapon, sizeof(weapon));
#endif

	if(!g_RoundOver)
		g_Spawned[client] = false;

	g_Hit[client] = false;
	
	// I would move this, but I'm not sure if it's used by STATS
	int playas = 0;
	for(int i=1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) /*&& !IsFakeClient(i)*/ && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_PROP)
		{
			playas++;
		}
	}
	
	if (GetClientTeam(client) == TEAM_PROP)
	{
		if(!g_RoundOver)
		{
			PH_EmitSoundToClient(client, "PropDeath");
		}
		
		// This is to kill the particle effects from the Harvest Ghost prop and the like
		// Moved to RED-only section so we don't kill unusual effects.
		// Reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/shared/particle_parse.cpp#L482
		SetVariantString("ParticleEffectStop");
		AcceptEntityInput(client, "DispatchEffect");
	}
	
	if(!g_RoundOver)
	{
		if(client > 0 && attacker > 0 && IsClientInGame(client) && IsClientInGame(attacker) && client != attacker)
		{
#if defined STATS
			PlayerKilled(clientID, attackerID, assisterID, weaponid, weapon);
#endif

			if(IsPlayerAlive(attacker))
			{
				Speedup(attacker);
				FillHealth(attacker);
			}
			
			if(assister > 0 && IsClientInGame(assister))
			{
				if(IsPlayerAlive(assister))
				{
					Speedup(assister);
					FillHealth(assister);
				}
			}
			
		}
		
		// We now manually handle First Blood and avoid having the crit effect.
		// We also adjust the various sound times to be more in line with PropHunt.
		if (!g_PlayerDied)
		{
			// Fast is 0-30, regular is 31-90, finally is 91+
			int expendedTime = RoundToNearest(GetGameTime() - g_flRoundStart);
			if (expendedTime <= 30)
			{
				PH_EmitSoundToAll("FirstBloodFast");
			}
			else if (expendedTime <= 90)
			{
				PH_EmitSoundToAll("FirstBlood");
			}
			else
			{
				PH_EmitSoundToAll("FirstBloodFinally");
			}
			
			g_PlayerDied = true;
		}

		if(!g_LastProp && playas == 2 && GetClientTeam(client) == TEAM_PROP)
		{
			g_LastProp = true;
			PH_EmitSoundToAll("OneAndOnly", _, _, SNDLEVEL_AIRCRAFT);
	#if defined SCATTERGUN
			for(int client2=1; client2 <= MaxClients; client2++)
			{
				if(IsClientInGame(client2) && !IsFakeClient(client2) && IsPlayerAlive(client2))
				{
					if(GetClientTeam(client2) == TEAM_PROP)
					{
						g_LastPropPlayer = client2;
						TF2_RegeneratePlayer(client2);
					// Replaced by TF2Items_OnGiveNamedItem_Post
					//CreateTimer(0.1, Timer_WeaponAlpha, GetClientUserId(client2));
					}
					else
					if(GetClientTeam(client2) == TEAM_HUNTER)
					{
						TF2_AddCondition(client2, TFCond_Jarated, 15.0);
					}
				}
			}
	#endif
		}
	}
	
	return Plugin_Continue;
}

//////////////////////////////////////////////////////
///////////////////  TIMERS  ////////////////////////
////////////////////////////////////////////////////

public Action Timer_Respawn(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0)
	{
		g_AllowedSpawn[client] = true;
		TF2_RespawnPlayer(client);
	}
}

public Action Timer_WeaponAlpha(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
		SetWeaponsAlpha(client, 0);
}

// This is used for the fading in of the game mode name and stuff
public Action Timer_Info(Handle timer)
{
	g_Message_bit++;

	if(g_Message_bit == 2)
	{
		SetHudTextParamsEx(-1.0, 0.22, 5.0, {0,204,255,255}, {0,0,0,255}, 2, 1.0, 0.05, 0.5);
		for(int i=1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, g_Text1, "PropHunt %s", g_Version);
			}
		}
	}
	else if(g_Message_bit == 3)
	{
		SetHudTextParamsEx(-1.0, 0.25, 4.0, {255,128,0,255}, {0,0,0,255}, 2, 1.0, 0.05, 0.5);
		for(int i=1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, g_Text2, "By Darkimmortal, Geit, and Powerlord");
			}
		}
	}
	else if(g_Message_bit == 4 && strlen(g_AdText) > 0)
	{
		SetHudTextParamsEx(-1.0, 0.3, 3.0, {0,220,0,255}, {0,0,0,255}, 2, 1.0, 0.05, 0.5);
		for(int i=1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				ShowSyncHudText(i, g_Text3, g_AdText);
			}
		}
	}
	
	if(g_Message_bit < 10 && IsValidEntity(g_Message_red) && IsValidEntity(g_Message_blue))
	{
		AcceptEntityInput(g_Message_red, "Display");
		AcceptEntityInput(g_Message_blue, "Display");
		CreateTimer(1.0, Timer_Info);
	}
}

//public Action:Timer_DoEquipBlu(Handle:timer, any:UserId)
public void DoEquipHunter(any UserId)
{
	int client = GetClientOfUserId(UserId);
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(g_inPreRound)
		{
			SetEntityMoveType(client, MOVETYPE_NONE);
		}

		SwitchView(client, false, true);
		SetAlpha(client, 255);
		
		int validWeapons;
		
		for (int i = 0; i < 3; i++)
		{
			int playerItemSlot = GetPlayerWeaponSlot(client, i);
			
			if(playerItemSlot > MaxClients && IsValidEntity(playerItemSlot))
			{
				validWeapons++;
			}
		}
		
		if(validWeapons == 0)
		{
			TF2_SetPlayerClass(client, TFClass_Pyro);
			g_AllowedSpawn[client] = true;
			TF2_RespawnPlayer(client);
		}
	}
}

//public Action:Timer_DoEquip(Handle:timer, any:UserId)
public void DoEquipProp(any UserId)
{
	int client = GetClientOfUserId(UserId);
	if(client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		//TF2_RegeneratePlayer(client);
		
#if defined LOG
		LogMessage("[PH] do equip %N", client);
#endif
		
		char pname[32];
		Format(pname, sizeof(pname), "ph_player_%i", client);
		DispatchKeyValue(client, "targetname", pname);
#if defined LOG
		LogMessage("[PH] do equip_2 %N", client);
#endif
		
		int propData[PropData];
		
		// fire in a nice random model
		char model[PLATFORM_MAX_PATH];
		char offset[32] = "0 0 0";
		char rotation[32] = "0 0 0";
		int skin = 0;		
		int modelIndex = -1;
		if(strlen(g_PlayerModel[client]) > 1)
		{
			model = g_PlayerModel[client];
			modelIndex = g_ModelName.FindString(model);
#if defined LOG
			LogMessage("Change user model to %s", model);
#endif
		}
		else
		{
			modelIndex = GetRandomInt(0, g_ModelName.Length-1);
			g_ModelName.GetString(modelIndex, model, sizeof(model));
		}
		
		// This wackiness with [0] is required when dealing with enums containing strings
		if (g_PropData.GetArray(model, propData[0], sizeof(propData)))
		{
			strcopy(offset, sizeof(offset), propData[PropData_Offset]);
			strcopy(rotation, sizeof(rotation), propData[PropData_Rotation]);
		}

		if (!g_RoundStartMessageSent[client])
		{
			char modelName[MAXMODELNAME];
			GetModelNameForClient(client, model, modelName, sizeof(modelName));
			CPrintToChat(client, "%t", "#TF_PH_NowDisguised", modelName);
			g_RoundStartMessageSent[client] = true;
		}
		
		if (modelIndex > -1)
		{
			char tempOffset[32];
			char tempRotation[32];
			g_ModelOffset.GetString(modelIndex, tempOffset, sizeof(tempOffset));
			g_ModelRotation.GetString(modelIndex, tempRotation, sizeof(tempRotation));
			TrimString(tempOffset);
			TrimString(tempRotation);
			// We don't want to override the default value unless it's set to something other than "0 0 0"
			if (!StrEqual(tempOffset, "0 0 0"))
			{
				strcopy(offset, sizeof(offset), tempOffset);
			}
			if (!StrEqual(tempRotation, "0 0 0"))
			{
				strcopy(rotation, sizeof(rotation), tempRotation);
			}
			skin = g_ModelSkin.Get(modelIndex);
		}
		
#if defined LOG
		LogMessage("[PH] do equip_3 %N", client);
#endif

#if defined LOG
		LogMessage("[PH] do equip_4 %N", client);
#endif
		// This is to kill the particle effects from the Harvest Ghost prop and the like
		SetVariantString("ParticleEffectStop");
		AcceptEntityInput(client, "DispatchEffect");
		
		g_PlayerModel[client] = model;
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");

		SetVariantString(offset);
		AcceptEntityInput(client, "SetCustomModelOffset");
		if (StrEqual(rotation, "0 0 0"))
		{
			AcceptEntityInput(client, "ClearCustomModelRotation");
		}
		else
		{
			SetVariantString(rotation);
			AcceptEntityInput(client, "SetCustomModelRotation");
		}
		SetVariantInt(1);
		AcceptEntityInput(client, "SetCustomModelRotates");
		if (skin > 0)
		{
			SetEntProp(client, Prop_Send, "m_bForcedSkin", true);
			SetEntProp(client, Prop_Send, "m_nForcedSkin", skin);
		}
		SwitchView(client, true, false);
#if defined LOG
		LogMessage("[PH] do equip_5 %N", client);
#endif
		
		if(!g_inPreRound)
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}

public Action Timer_Locked(Handle timer, any entity)
{
	for(int client=1; client <= MaxClients; client++)
	{
		if(g_RotLocked[client] && IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_PROP)
		{
			SetHudTextParamsEx(0.05, 0.05, 0.7, { /*0,204,255*/ 220, 90, 0, 255}, {0,0,0,0}, 1, 0.2, 0.2, 0.2);
			ShowSyncHudText(client, g_Text4, "PropLock Engaged");
		}
	}
}

public Action Timer_AntiHack(Handle timer, any entity)
{
	int red = TEAM_PROP - 2;
	if(!g_RoundOver)
	{
		char name[MAX_NAME_LENGTH];
		for(int client=1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && IsPlayerAlive(client))
			{
				if (g_PHStaticPropInfo.BoolValue && !IsFakeClient(client))
				{
					QueryClientConVar(client, "r_staticpropinfo", QueryStaticProp);
				}
				
				if(!g_LastProp && g_PHAntiHack.BoolValue && GetClientTeam(client) == TEAM_PROP && TF2_GetPlayerClass(client) == g_defaultClass[red])
				{
					if(GetPlayerWeaponSlot(client, 1) != -1 || GetPlayerWeaponSlot(client, 0) != -1 || GetPlayerWeaponSlot(client, 2) != -1)
					{
						GetClientName(client, name, sizeof(name));
						CPrintToChatAll("%t", "#TF_PH_WeaponPunish", name);
						SwitchView(client, false, true);
						//ForcePlayerSuicide(client);
						g_PlayerModel[client] = "";
						TF2_RemoveAllWeapons(client); // This really needs to be left on
						//Timer_DoEquip(INVALID_HANDLE, GetClientUserId(client));
						RequestFrame(FixPropPlayer, GetClientUserId(client));
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

// Fix a prop player who still had weapons
// One frame shouldn't be enough to change players, but just in case...
public void FixPropPlayer(any userid)
{
	int client = GetClientOfUserId(userid);
	if (client < 1 || GetClientTeam(client) != TEAM_PROP || g_LastProp)
		return;
	
	//TF2_RegeneratePlayer(client);
	
	TF2_RemoveAllWeapons(client);	
	
	//Timer_DoEquip(INVALID_HANDLE, userid);
	RequestFrame(DoEquipProp, userid);
}

public void QueryStaticProp(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (result == ConVarQuery_Okay)
	{
		int value = StringToInt(cvarValue);
		if (value == 0)
		{
			return;
		}
		KickClient(client, "r_staticpropinfo was enabled");
		return;
	}
	KickClient(client, "r_staticpropinfo detection was blocked");
}

public Action Timer_Ragdoll(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client < 1)
		return Plugin_Handled;
	
	int rag = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if(rag > MaxClients && IsValidEntity(rag))
	AcceptEntityInput(rag, "Kill");

	RemovePropModel(client);
	
	return Plugin_Handled;
}

public Action Timer_Score(Handle timer)
{
	for(int client=1; client <= MaxClients; client++)
	{
#if defined STATS
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_PROP)
		{
			AlterScore(client, 2, ScReason_Time, 0);
		}
#endif
		g_TouchingCP[client] = false;
	}
	CPrintToChatAll("%t", "#TF_PH_CPBonusRefreshed");
}

public void OnSetupStart(const char[] output, int caller, int activator, float delay)
{
	g_inSetup = true;
	Event event = CreateEvent("teamplay_update_timer");
	if (event != null)
		event.Fire();
}

// This used to hook the teamplay_setup_finished event, but ph_kakariko messes with that
public void OnSetupFinished(const char[] output, int caller, int activator, float delay)
{
	if (g_hScore != null)
	{
		delete g_hScore;
	}
	g_hScore = CreateTimer(55.0, Timer_Score, _, TIMER_REPEAT);
	TriggerTimer(g_hScore);
	
#if defined LOG
	LogMessage("[PH] Setup_Finish");
#endif
	g_RoundOver = false;
	g_inSetup = false;
	g_flRoundStart = GetGameTime();

	for(int client2=1; client2 <= MaxClients; client2++)
	{
		if(IsClientInGame(client2) && IsPlayerAlive(client2))
		{
			SetEntityMoveType(client2, MOVETYPE_WALK);
		}
	}
	CPrintToChatAll("%t", "#TF_PH_PyrosReleased");
	PH_EmitSoundToAll("RoundStart", _, _, SNDLEVEL_AIRCRAFT);

	int ent;
	if(g_Doors)
	{
		while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
		{
			AcceptEntityInput(ent, "Open");
		}
	}

	if(g_Relay)
	{
		char relayName[128];
		while ((ent = FindEntityByClassname(ent, "logic_relay")) != -1)
		{
			GetEntPropString(ent, Prop_Data, "m_iName", relayName, sizeof(relayName));
			if(strcmp(relayName, "hidingover", false) == 0)
			AcceptEntityInput(ent, "Trigger");
		}
	}
//	g_TimerStart = INVALID_HANDLE;
	//return Plugin_Handled;

}

#if defined CHARGE
public Action Timer_Charge(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	int red = TEAM_PROP-2;
	if(client > 0 && IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
		TF2_SetPlayerClass(client, g_defaultClass[red], false);
	}
	return Plugin_Handled;
}
#endif

public Action Timer_Unfreeze(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0 && IsPlayerAlive(client))
		SetEntityMoveType(client, MOVETYPE_WALK);
	return Plugin_Handled;
}

public Action Timer_Move(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0)
	{
		g_AllowedSpawn[client] = false;
		if(IsPlayerAlive(client))
		{
			int rag = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
			if(IsValidEntity(rag))
			AcceptEntityInput(rag, "Kill");
			SetEntityMoveType(client, MOVETYPE_WALK);
			if(GetClientTeam(client) == TEAM_HUNTER)
			{
				RequestFrame(DoEquipHunter, GetClientUserId(client));
			}
			else
			{
				//CreateTimer(0.1, Timer_DoEquip, GetClientUserId(client));
				RequestFrame(DoEquipProp, GetClientUserId(client));
			}
		}
	}
	return Plugin_Handled;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)
{
	// This section is to prevent Handle leaks
	static Handle weapon = null;
	if (weapon != null)
	{
		delete weapon;
	}
	
	if (!g_Enabled)
		return Plugin_Continue;
	
	// Spectators shouldn't have their items
	if (IsClientObserver(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	// Block canteens and spellbooks for all players as the game will only check them ONCE
	// If they're ever shown, they will only end up in this block again if a different action item is equipped
	if (StrEqual(classname, "tf_powerup_bottle", false) || StrEqual(classname, "tf_weapon_spellbook", false))
	{
		return Plugin_Stop;
	}
	
	int team = GetClientTeam(client);
	
	if (team == TEAM_PROP)
	{
		// Taunt items have the classname "no_entity" now
		if (g_PHAllowTaunts.BoolValue && StrEqual(classname, "no_entity", false))
		{
			return Plugin_Continue;
		}
		
		// If they're not the last prop, don't give them anything
		if (!g_LastProp)
		{
			return Plugin_Stop;
		}
	
		// Block wearables for Props
		// From testing, Action items still work even if you block them
		// Note: The Love and War update seems to have changed that, as taunt items won't work unless the taunt menu 
		//  was open before round start and can only be used once
		if (StrEqual(classname, "tf_wearable", false))
		{
			return Plugin_Stop;
		}

		if (g_hPropWeaponRemovals.FindValue(iItemDefinitionIndex) >= 0)
		{
			return Plugin_Stop;
		}
	}

	char defIndex[7];
	IntToString(iItemDefinitionIndex, defIndex, sizeof(defIndex));
	
	int flags;	
	
	char replacement[140];
	char addAttributes[128];
	bool replace = g_hWeaponReplacements.GetString(defIndex, replacement, sizeof(replacement));
	bool stripattribs = g_hWeaponStripAttribs.FindValue(iItemDefinitionIndex) >= 0;
	bool addattribs = g_hWeaponAddAttribs.GetString(defIndex, addAttributes, sizeof(addAttributes));
	bool removeAirblast = !g_PHAirblast.BoolValue && StrEqual(classname, "tf_weapon_flamethrower");

	if (replace)
	{
		int classBits;
		
		if (!g_hWeaponReplacementPlayerClasses.GetValue(defIndex, classBits))
		{
			g_Replacements[client][g_ReplacementCount[client]++] = iItemDefinitionIndex;
			return Plugin_Stop;
		}
		else
		{
			// We subtract 1 here because we're left shifting a 1, so 1 is intrinsically added to the class.
			int class = view_as<int>(TF2_GetPlayerClass(client)) - 1;
			if (classBits & (1 << class))
			{
				g_Replacements[client][g_ReplacementCount[client]++] = iItemDefinitionIndex;
				return Plugin_Stop;
			}
		}
		replace = false;
	}

	// If we're supposed to remove it, just block it here
	if (team == TEAM_HUNTER && g_hWeaponRemovals.FindValue(iItemDefinitionIndex) >= 0)
	{
		return Plugin_Stop;
	}
	
	if (!replace && !stripattribs && !addattribs && !removeAirblast)
	{
		return Plugin_Continue;
	}
	
	bool weaponChanged = false;
	
	if (stripattribs)
	{
		weaponChanged = true;
	}
	else
	{
		flags |= PRESERVE_ATTRIBUTES;
	}
	
	flags |= OVERRIDE_ATTRIBUTES;
	
	weapon = TF2Items_CreateItem(flags);

	int attribCount = 0;
	// 594 is Phlogistinator and already has airblast disabled
	if (removeAirblast && (iItemDefinitionIndex != WEP_PHLOGISTINATOR || stripattribs))
	{
		TF2Items_SetAttribute(weapon, attribCount++, 356, 1.0); // "airblast disabled"
		weaponChanged = true;
	}
	
	if (addattribs)
	{
		// Pawn is dumb and this "shadows" a preceding variable despite being at a different block level
		char newAttribs2[32][6];
		int count = ExplodeString(addAttributes, ";", newAttribs2, sizeof(newAttribs2), sizeof(newAttribs2[]));
		if (count % 2 > 0)
		{
			LogError("Error parsing additional attributes for item definition index %d", iItemDefinitionIndex);
			return Plugin_Continue;
		}
		
		for (int i = 0; i < count && attribCount < 16; i += 2)
		{
			TrimString(newAttribs2[i]);
			TrimString(newAttribs2[i+1]);
			int attrib = StringToInt(newAttribs2[i]);
			float value = StringToFloat(newAttribs2[i+1]);
			TF2Items_SetAttribute(weapon, attribCount++, attrib, value);
		}
	}
	
	if (attribCount > 0)
	{
		TF2Items_SetNumAttributes(weapon, attribCount);
		weaponChanged = true;
	}
		
	if (weaponChanged)
	{
		hItem = weapon;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

#if defined OIMM
public void MultiMod_Status(bool enabled)
{
	g_PHEnable.BoolValue = enabled
}

public void MultiMod_TranslateName(int client, char[] translation, int maxlength)
{
	Format(translation, maxlength, "%T", "#TF_PH_ModeName", client);
}
#endif

public bool ValidateMap(const char[] map)
{
	return FindConfigFileForMap(map);
}

// These functions are based on versions taken from CS:S/CS:GO Hide and Seek
int GetLanguageID(const char[] langCode)
{
	return g_ModelLanguages.FindString(langCode);
}

int GetClientLanguageID(int client, char[] languageCode="", int maxlen=0)
{
	char langCode[MAXLANGUAGECODE];
	int languageID;
	if (client == LANG_SERVER)
	{
		languageID = GetServerLanguage();
	}
	else
	{
		languageID = GetClientLanguage(client);
	}
	
	GetLanguageInfo(languageID, langCode, sizeof(langCode));
#if defined LOG
	LogMessage("Client is using language code %s", langCode);
#endif
	// is client's prefered language available?
	int langID = GetLanguageID(langCode);
	if(langID != -1)
	{
		strcopy(languageCode, maxlen, langCode);
		return langID; // yes.
	}
	else
	{
#if defined LOG
		LogMessage("PH language code \"%s\" not found.", langCode);
#endif
		GetLanguageInfo(GetServerLanguage(), langCode, sizeof(langCode));
#if defined LOG
		LogMessage("Falling back to server language code \"%s\".", langCode);
#endif
		// is default server language available?
		langID = GetLanguageID(langCode);
		if(langID != -1)
		{
			strcopy(languageCode, maxlen, langCode);
			return langID; // yes.
		}
		else
		{
#if defined LOG
			LogMessage("PH language \"%s\" not found, Falling back to \"en\".", langCode);
#endif
			// default to english
			langID = GetLanguageID("en");
			
			if (langID != -1)
			{
				strcopy(languageCode, maxlen, "en");
				return langID;
			}
			
			// english not found? happens on custom map configs e.g.
			// use the first language available
			// this should always work, since we would have SetFailState() on parse
			if(g_ModelLanguages.Length > 0)
			{
#if defined LOG
				LogMessage("PH language \"en\" not found, Falling back to lang 0.");
#endif
				g_ModelLanguages.GetString(0, languageCode, maxlen);
				return 0;
			}
		}
	}
	// this should never happen
	return -1;
}

bool GetModelNameForClient(int client, const char[] modelName, char[] name, int maxlen)
{
	if (g_PHMultilingual.BoolValue)
	{
		char langCode[MAXLANGUAGECODE];
		
		GetClientLanguageID(client, langCode, sizeof(langCode));
#if defined LOG
		LogMessage("[PH] Retrieving %s name for %s", langCode, modelName);
#endif	
		StringMap languageTrie;
		if (strlen(langCode) > 0 && g_PropNames.GetValue(modelName, languageTrie) && languageTrie != null && languageTrie.GetString(langCode, name, maxlen))
		{
			return true;
		}
		else
		{
			strcopy(name, maxlen, modelName);
			return false;
		}
	}
	else
	{
		int propData[PropData];
		
		if (g_PropData.GetArray(modelName, propData[0], sizeof(propData)))
		{
			strcopy(name, maxlen, propData[PropData_Name]);
			return true;
		}
		else
		{
			strcopy(name, maxlen, modelName);
			return false;
		}
	}
}

// Fix for weapon alphas for last prop
public int TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	if (g_LastProp && g_LastPropPlayer == client && IsValidEntity(entityIndex))
	{
		SetItemAlpha(entityIndex, 0);
	}
}

bool HasSwitchedTeams()
{
	return view_as<bool>(GameRules_GetProp("m_bSwitchedTeamsThisRound"));
}

void SetSwitchTeams(bool bSwitchTeams)
{
	// Note, this doesn't switch team scores... those are switched when SetWinner is called in the game
	// Also, SetWinner will override our selection here, so this must be sent AFTER arena_win_panel fires
	SDKCall(g_hSwitchTeams, bSwitchTeams);
}

// Manually switch the scores.
// The game only does this if SetWinningTeam is called with bSwitchTeams set to true.
// This is what DHooks did, but Arena confused it anyway and it only sometimes worked
void SwitchTeamScoresClassic()
{
	int propScore = GetTeamScore(TEAM_PROP);
	int hunterScore = GetTeamScore(TEAM_HUNTER);
	
	if (propScore == 0 && hunterScore == 0)
	{
		return;
	}
	
#if defined LOG
	LogMessage("[PH] Swapping team scores: Props: %d, Hunters: %d", propScore, hunterScore);
#endif

	SetTeamScore(TEAM_PROP, hunterScore);
	SetTeamScore(TEAM_HUNTER, propScore);
}

bool FindConfigFileForMap(const char[] map, char[] destination = "", int maxlen = 0)
{
	char mapPiece[PLATFORM_MAX_PATH];
	
#if defined WORKSHOP_SUPPORT
	// Handle workshop maps
	if (GetFeatureStatus(FeatureType_Native, "GetMapDisplayName") == FeatureStatus_Available)
	{
		if (!GetMapDisplayName(map, mapPiece, sizeof(mapPiece)))
		{
			return false;
		}
	}
	else
	{
#endif
		strcopy(mapPiece, sizeof(mapPiece), map);
		
		if (!IsMapValid(mapPiece))
		{
			return false;
		}
#if defined WORKSHOP_SUPPORT
	}
#endif
	char confil[PLATFORM_MAX_PATH];
	
	// Optimization so we don't immediately rebuild the whole string after ExplodeString
	BuildPath(Path_SM, confil, sizeof(confil), "data/prophunt/maps/%s.cfg", mapPiece);
	if (FileExists(confil, true))
	{
		strcopy(destination, maxlen, confil);
		return true;
	}
	
	char fileParts[4][PLATFORM_MAX_PATH];
	int count = ExplodeString(mapPiece, "_", fileParts, sizeof(fileParts), sizeof(fileParts[])) - 1;
	
	while (count > 0)
	{
		mapPiece[0] = '\0';
		ImplodeStrings(fileParts, count, "_", mapPiece, sizeof(mapPiece));
		
		BuildPath(Path_SM, confil, sizeof(confil), "data/prophunt/maps/%s.cfg", mapPiece);
		
		if (FileExists(confil, true))
		{
			strcopy(destination, maxlen, confil);
			return true;
		}
		
		count--;
	}
	
	destination[0] = '\0'; // In case of decl
	return false;
}

// Natives

public int Native_ValidateMap(Handle plugin, int numParams)
{
	int mapLength;
	GetNativeStringLength(1, mapLength);
	
	char[] map = new char[mapLength+1];
	GetNativeString(1, map, mapLength+1);
	
	return ValidateMap(map);
}

public int Native_IsRunning(Handle plugin, int numParams)
{
	return g_Enabled;
}

public int Native_GetModel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_PROP || strlen(g_PlayerModel[client]) == 0)
	{
		return false;
	}
	
	SetNativeString(2, g_PlayerModel[client], GetNativeCell(3));
	
	return true;
}

public int Native_GetModelName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_PROP || strlen(g_PlayerModel[client]) == 0)
	{
		return false;
	}
	
	int targetClient = GetNativeCell(4);
	
	int length = GetNativeCell(3);
	char[] model = new char[length];
	
	GetModelNameForClient(targetClient, g_PlayerModel[client], model, length);
	
	SetNativeString(2, model, length);
	return true;
}

public int Native_LastPropMode(Handle plugin, int numParams)
{
	return g_LastProp;
}

void Internal_AddServerTag()
{
	char tags[SV_TAGS_SIZE+1];
	g_hTags.GetString(tags, sizeof(tags));
	
	if (StrContains(tags, "PropHunt", false) == -1 && strlen(tags) + 9 <= SV_TAGS_SIZE)
	{
		char tagArray[20][SV_TAGS_SIZE+1];
		int count = ExplodeString(tags, ",", tagArray, sizeof(tagArray), sizeof(tagArray[]));

		if (count < sizeof(tagArray))
		{
			tagArray[count] = "PropHunt";
			
			ImplodeStrings(tagArray, count+1, ",", tags, sizeof(tags));
			SetConVarString(g_hTags, tags);
		}
	}
}

void Internal_RemoveServerTag()
{
	char tags[SV_TAGS_SIZE+1];
	g_hTags.GetString(tags, sizeof(tags));
	
	if (StrContains(tags, "PropHunt", false) > -1)
	{
		char tagArray[20][SV_TAGS_SIZE+1];
		int count = ExplodeString(tags, ",", tagArray, sizeof(tagArray), sizeof(tagArray[]));

		for (int i = count - 1; i >= 0; i--)
		{
			TrimString(tagArray[i]);
			if (StrEqual(tagArray[i], "PropHunt", false))
			{
				count--;

				// Move all elements above this one down by one
				for (int j = i; j < count; j++)
				{
					tagArray[j] = tagArray[j+1];
				}
				tagArray[count][0] = '\0';
			}
		}
		
		ImplodeStrings(tagArray, count, ",", tags, sizeof(tags));
		g_hTags.SetString(tags);
	}
	
}

// Below this point are the forward calls
// They're here so we have the code to call them organized.
/*
stock void DbRound(int winner)
{
	Call_StartForward(g_fStatsRoundWin);
	Call_PushCell(winner);
	Call_Finish();
}

stock void AlterScore(int client, ScReason reason)
{
	Call_StartForward(g_fStatsAlterScore);
	Call_PushCell(client);
	Call_PushCell(reason);
	Call_Finish();
}

stock void PlayerKilled(int clientID, int attackerID, int assisterID, int weaponid, const char[] weapon)
{
	Call_StartForward(g_fStatsPlayerKilled);
	Call_PushCell(clientID);
	Call_PushCell(attackerID);
	Call_PushCell(assisterID);
	Call_PushCell(weaponID);
	Call_PushString(weapon);
	Call_Finish();
}
*/
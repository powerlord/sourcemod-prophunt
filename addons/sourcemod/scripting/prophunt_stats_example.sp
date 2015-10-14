/**
 * vim: set ts=4 :
 * =============================================================================
 * PropHunt Stats Example
 * Example on how to do PropHunt Stats Stuff using a DB connection
 *
 * PropHunt Stats Example (C)2015 Powerlord (Ross Bemrose).  All rights reserved.
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
 * Version: $Id$
 */
#include <sourcemod>
#include "include/prophunt"
#include <tf2_stocks>
#include <tf2>
#include <geoip>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

#define VERSION "4.0.0 alpha 1"

#define DATABASE "prophuntstats"

enum ScReason
{
	ScReason_TeamWin = 0,
	ScReason_TeamLose,
	ScReason_Death, // Not used in default scoring
	ScReason_Kill, // Not used in default scoring
	ScReason_Time,
	ScReason_Friendly // Not used in default scoring, friendly fire has been disabled by default in PH for years.
};

//#define LOGSTATS 1

// AuthID_Steam2 (STEAM_0:0:123456789) uses 19 characters (may be 20 soon)
// AuthID_Steam3 ([U:1:1234567] uses 13 (may be 14) or more characters.  I would recommend setting to at least 18.
// AuthId_SteamID64 (765345678901234567) uses 17 characters
const AuthIdType SteamIdType = AuthId_Steam2;
const int SteamIdLength = 20; // STEAM_0:0:1234567890 <-- this is 1 larger than currently needed, but just to make sure...

const int Points_Time = 2;
const int Points_TeamWin = 3;
const int Points_TeamLose = -1;

// How many points are awarded for each action?
// Note that victims lose half the killer's points
// (Killer gains 2, victim loses 1; kiler gains 8, victim loses 4)
const int Points_Killer_Min = 2;
const int Points_Killer_Max = 8;
const int Points_Assister_Min = 1;
const int Points_Assister_Max = 8;

// What lengths do we use for escaped strings?
const int SQLNameLength = MAX_NAME_LENGTH*2+1;
const int SQLSteamIdLength = SteamIdLength*2+1;
const int SQLPathLength = PLATFORM_MAX_PATH*2+1;

// Which field in a transaction is the SELECT query?
const int TransactionData = 1;

// 60.0 * 60.0
const float SecondsPerHour = 3600.0;

char ignore[16];

ConVar g_Cvar_Enabled;

Database g_StatsDB;
Handle g_hScoreTimer;

bool isPropHuntRound = false;

int g_ServerPointCount;
int g_PointCount[MAXPLAYERS+1];
int g_ClientTime[MAXPLAYERS+1];
int g_ServerTime;

char g_ServerIP[32];
//char g_ServerHostname[128];
//int g_ServerPort;

char g_SteamID[MAXPLAYERS+1][SteamIdLength+1];

bool g_inRound = false;

int g_StartTime;

/*
enum DBType
{
	DBType_Unknown,
	DBType_MySQL,
	DBType_SQLite,
	DBType_PostgreSQL
}

DBType g_DBType = DBType_Unknown;
*/

public Plugin myinfo = {
	name			= "PropHunt Redux Stats",
	author			= "Powerlord",
	description		= "PropHunt stats using a database",
	version			= VERSION,
	url				= ""
};

// SOURCEMOD CALLBACKS

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		strcopy(error, err_max, "PropHunt Redux Stats only works on Team Fortress 2.");
		return APLRes_Failure;
	}
	
	if (late)
	{
		strcopy(error, err_max, "PropHunt Redux Stats does not support late loading.");
		return APLRes_Failure;
	}
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("prophunt.phrases");
	
	CreateConVar("prophunt_stats_example_version", VERSION, "PropHunt Stats version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	g_Cvar_Enabled = CreateConVar("prophunt_stats_example_enable", "1", "Enable PropHunt Stats Example?", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("teamplay_round_win", Event_RoundWin);
	HookEvent("player_death", Event_PlayerDeath);

	RegConsoleCmd("rank", Cmd_Rank);
	RegConsoleCmd("statsme", Cmd_StatsMe);
	RegConsoleCmd("top10", Cmd_Top10);

	char ip[16]; // 123.567.901.345\0
	int port = FindConVar("hostport").IntValue;
	FindConVar("ip").GetString(ip, sizeof(ip));
	Format(g_ServerIP, sizeof(g_ServerIP), "%s:%d", ip, port);
	
	Stats_Init();
}


public void OnPluginEnd()
{
	delete g_StatsDB;
}

public void OnMapStart()
{
	// assume false until round start
	isPropHuntRound = false;
	
	g_inRound = false;
}

public void OnClientConnected(int client)
{
	// This is to deal with their connect time in case this was a map change
	g_ClientTime[client] = RoundFloat(GetClientTime(client));
}

public void OnClientPostAdminCheck(int client)
{
	// Get PropHunt stats even if this isn't a PH round
	if (!IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	char steamid[SteamIdLength+1];
	char name[MAX_NAME_LENGTH+1];
	
	if (!GetClientAuthId(client, SteamIdType, g_SteamID[client], sizeof(g_SteamID[])))
	{
		LogMessage("Steam ID lookup failed for clent %d (\"%N\")", client, client);
		return;
	}
	
	char escapedSteamid[SQLSteamIdLength];
	g_StatsDB.Escape(steamid, escapedSteamid, sizeof(escapedSteamid));
	
	char escapedName[SQLNameLength];
	g_StatsDB.Escape(name, escapedName, sizeof(escapedName));
	
	int userId = GetClientUserId(client);
	
	Transaction tx = new Transaction();
	
	char query[384];
	Format(query, sizeof(query), "INSERT %s INTO players (steamid, name) VALUES('%s', '%s')", ignore, escapedSteamid, escapedName);
	tx.AddQuery(query);
	
	Format(query, sizeof(query), "SELECT points FROM players WHERE steamid='%s'", escapedSteamid);
	tx.AddQuery(query);
	
	g_StatsDB.Execute(tx, Tx_PlayerConnect, Tx_Error, userId, DBPrio_High);
}

public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && DatabaseIntact())
	{
		char query[392], ip[32], geoip[3], name[MAX_NAME_LENGTH+1];
		
		GetClientName(client, name, sizeof(name));
		
		char escapedSteamid[SQLSteamIdLength];
		g_StatsDB.Escape(g_SteamID[client], escapedSteamid, sizeof(escapedSteamid));
		
		char escapedName[SQLNameLength];
		g_StatsDB.Escape(name, escapedName, sizeof(escapedName));
		
		Transaction tx = new Transaction();
		Format(query, sizeof(query), "INSERT %s INTO players (steamid, name) VALUES('%s', '%s')", ignore, escapedSteamid, escapedName);
		tx.AddQuery(query);
		
		int clientTime = RoundFloat(GetClientTime(client));
		Format(query, sizeof(query), "UPDATE players SET lastserver = '%s', time = time + %d, ip = '%s', geoip = '%s', name = '%s' WHERE steamid = '%s'",
			g_ServerIP, clientTime - g_ClientTime[client], ip, geoip, escapedName, escapedSteamid);
		tx.AddQuery(query);
		
		g_StatsDB.Execute(tx, .onError=Tx_Error);
	}
	
	g_ClientTime[client] = 0;
	g_SteamID[client][0] = '\0';
}

// COMMANDS

public Action Cmd_StatsMe(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (IsClientInGame(client) && DatabaseIntact())
	{
		char query[392];
		
		char escapedSteamid[SQLSteamIdLength];
		g_StatsDB.Escape(g_SteamID[client], escapedSteamid, sizeof(escapedSteamid));
		
		Format(query, sizeof(query), "SELECT points, wins, losses, a.rank, time FROM players, (SELECT count(*)+1 as rank FROM players WHERE points > (SELECT points FROM players WHERE steamid = '%s')) as a WHERE steamid = '%s'", escapedSteamid, escapedSteamid);
		g_StatsDB.Query(T_Statsme, query, GetClientUserId(client));
	}
	
	return Plugin_Handled;
}

public Action Cmd_Rank(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (IsClientInGame(client) && DatabaseIntact())
	{
		char query[392];
		
		char escapedSteamid[SQLSteamIdLength];
		g_StatsDB.Escape(g_SteamID[client], escapedSteamid, sizeof(escapedSteamid));
		
		Format(query, sizeof(query), "SELECT points, wins, losses, a.rank, time FROM players, (SELECT count(*)+1 as rank FROM players WHERE points > (SELECT points FROM players WHERE steamid = '%s')) as a WHERE steamid = '%s'", escapedSteamid, escapedSteamid);
		g_StatsDB.Query(T_Rank, query, GetClientUserId(client));
	}
	
	return Plugin_Handled;
}

public Action Cmd_Top10(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (IsClientInGame(client) && DatabaseIntact())
	{
		g_StatsDB.Query(T_Top10, "SELECT name, points FROM players ORDER BY points DESC LIMIT 10", GetClientUserId(client));
	}

	return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	isPropHuntRound = PropHuntRedux_IsRunning(); // This can change every round
	
	g_inRound = false;
	
	if (!g_Cvar_Enabled.BoolValue || !isPropHuntRound)
	{
		return;
	}
	
	g_hScoreTimer = CreateTimer(55.0, Timer_Score, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_inRound = true;
	g_StartTime = GetTime();
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Cvar_Enabled.BoolValue || !isPropHuntRound)
	{
		return;
	}
		
	g_inRound = false;
	isPropHuntRound = false;

	delete g_hScoreTimer;
	
	int winner = event.GetInt("team");
	
	DbRound(winner);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
		{
			continue;
		}
		
		int team = GetClientTeam(client);
		
		if (team == winner) // either props or hunters
		{
			AlterScore(client, Points_TeamWin, ScReason_TeamWin);
		}
		else if (team > TEAM_SPECTATOR) // either props or hunters
		{
			AlterScore(client, Points_TeamLose, ScReason_TeamLose);
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Cvar_Enabled.BoolValue || !g_inRound || !isPropHuntRound)
	{
		return;
	}
	
	// PropHunt usually doesn't allow Spies, but just in case
	if (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));
	
	char weapon[255];
	event.GetString("weapon_logclassname", weapon, sizeof(weapon));
	
	if (client > 0 && attacker > 0 && IsClientInGame(client) && IsClientInGame(attacker) && client != attacker)
	{
		PlayerKilled(client, attacker, assister, weapon);
	}
}

// FUNCTIONS

void PlayerKilled(int client, int attacker, int assister, char[] weaponname)
{
	int clientPoints, attackerPoints, assisterPoints;
	char attackerName[MAX_NAME_LENGTH+1], clientName[MAX_NAME_LENGTH+1];
	
	GetClientName(attacker, attackerName, sizeof(attackerName));
	GetClientName(client, clientName, sizeof(clientName));
	
	// This algorithm has corrects a long-standing bug in PropHunt stats where the float conversion was done after
	// int math had already taken place
	attackerPoints = RoundFloat(float(g_PointCount[client]) / float(g_PointCount[attacker]));
	
	// Point caps
	if (attackerPoints < Points_Killer_Min)
		attackerPoints = Points_Killer_Min;
	else if (attackerPoints > Points_Killer_Max)
		attackerPoints = Points_Killer_Max;
	
	//Assister point caps
	if (assister > 0)
	{
		assisterPoints = RoundFloat(float(g_PointCount[client]) / float(g_PointCount[assister]) / 2.0);
		
		if (assisterPoints < Points_Assister_Min)
			assisterPoints = Points_Assister_Min;
		else if (assisterPoints > Points_Assister_Max)
			assisterPoints = Points_Assister_Max;
	}
	
	// victim points are between -1 and -4
	clientPoints = 0 - RoundFloat(attackerPoints * 0.5);
	
	if (IsClientInGame(attacker))
	{
		if (GetClientTeam(client) == TEAM_PROP)
		{
			char model[PLATFORM_MAX_PATH];
			PropHuntRedux_GetPropModel(client, model, sizeof(model));
			DbProp(model, "death", 1);
		}
		CPrintToChat(client, "%t", "#TF_PH_AlterScore_Death", attackerName, clientPoints*-1);
		DbInt(client, "points", clientPoints);
	}
	
	CPrintToChat(attacker, "%t", "#TF_PH_AlterScore_Kill", clientName, attackerPoints);
	if (assister > 0)
		CPrintToChat(assister, "%t", "#TF_PH_AlterScore_Assist", clientName, assisterPoints);
	
	DbInt(attacker, "points", attackerPoints);
	if (assister > 0)
		DbInt(assister, "points", assisterPoints);
		
	// This is commented as we already subtract points from clients
	// DbInt(client, "points", -2);
	DbDeaths(client, attacker, assister, weaponname);
}

void DbDeaths(int client, int attacker, int assister, char[] weaponname)
{
	if (!DatabaseIntact() || !g_inRound)
	{
		return;
	}
		
	char query[1024], map[PLATFORM_MAX_PATH], escapedMap[SQLPathLength], model[PLATFORM_MAX_PATH], escapedModel[SQLPathLength];
	int team, time;
	float killerPos[3], victimPos[3];
	char escapedVictimId[SQLSteamIdLength], escapedKillerId[SQLSteamIdLength], escapedAssisterId[SQLSteamIdLength];
	
	// Ditch the legacy code dealing with weapon names
	
	if (client > 0 && !IsFakeClient(client) && IsClientInGame(client))
	{
		g_StatsDB.Escape(g_SteamID[client], escapedVictimId, sizeof(escapedVictimId));
		
		GetClientEyePosition(client, victimPos);
		time - GetTime() - g_StartTime;
	}
	
	if (attacker > 0 && !IsFakeClient(attacker) && IsClientInGame(attacker))
	{
		g_StatsDB.Escape(g_SteamID[attacker], escapedKillerId, sizeof(escapedKillerId));
		
		GetClientEyePosition(attacker, killerPos);
		team = GetClientTeam(attacker);
	}
	
	if (assister > 0 && !IsFakeClient(assister) && IsClientInGame(assister))
	{
		g_StatsDB.Escape(g_SteamID[assister], escapedAssisterId, sizeof(escapedAssisterId));
	}
	
	GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, map, sizeof(map));
	g_StatsDB.Escape(map, escapedMap, sizeof(escapedMap));
	
	PropHuntRedux_GetPropModel(client, model, sizeof(model));
	g_StatsDB.Escape(model, escapedModel, sizeof(escapedModel));
	
	Format(query, sizeof(query), "INSERT INTO deaths (victimid, killerid, killerteam, weapon, assisterid, ip, map, prop, victim_position_x, victim_position_y, victim_position_z, killer_position_x, killer_position_y, killer_position_z, victim_class, killer_class, survival_time) VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %.0f, %.0f, %.0f, %.0f, %.0f, %.0f, %i, %i, %i)",
		escapedVictimId, escapedKillerId, (team == TEAM_PROP ? "RED" : "BLU"), weaponname, escapedAssisterId, g_ServerIP, escapedMap, escapedModel, victimPos[0], victimPos[1], victimPos[2],
		killerPos[0], killerPos[1], killerPos[2], TF2_GetPlayerClass(client), TF2_GetPlayerClass(attacker), time);
	
	g_StatsDB.Query(T_ErrorOnly, query);
	
#if defined LOGSTATS
	LogMessage("[PH] DbDeaths [%s]", query);
#endif
}

void DbSurvivals(int client)
{
	if (!DatabaseIntact())
	{
		return;
	}
	
	char query[1024], map[PLATFORM_MAX_PATH], escapedMap[SQLPathLength], model[PLATFORM_MAX_PATH], escapedModel[SQLPathLength], escapedSteamid[SQLSteamIdLength];
	int time;
	float pos[3];
	
	if (client > 0 && !IsFakeClient(client) && IsClientInGame(client))
	{
		g_StatsDB.Escape(g_SteamID[client], escapedSteamid, sizeof(escapedSteamid));
		GetClientEyePosition(client, pos);
		time = GetTime() - g_StartTime;
	}
	
	GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, map, sizeof(map));
	g_StatsDB.Escape(map, escapedMap, sizeof(escapedMap));
	
	PropHuntRedux_GetPropModel(client, model, sizeof(model));
	g_StatsDB.Escape(model, escapedModel, sizeof(escapedModel));
	
	Format(query, sizeof(query), "INSERT INTO survivals (steamid, prop, ip, map, lastprop, position_x, position_y, position_z, class, team, survival_time) VALUES('%s', '%s', '%s', '%s', '%s', %.0f, %.0f, %.0f, %i, '%s', %i)",
		escapedSteamid, escapedModel, g_ServerIP, escapedMap, PropHuntRedux_IsLastPropMode() ? "1" : "0" , pos[0], pos[1], pos[2], TF2_GetPlayerClass(client),
		GetClientTeam(client) == TEAM_PROP ? "RED" : "BLU", time);
	
	g_StatsDB.Query(T_ErrorOnly, query);
	
#if defined LOGSTATS
	LogMessage("[PH] DbSurvivals [%s]", query);
#endif
}

void AlterScore(int client, int sc, ScReason reason)
{
	switch(reason)
	{
		case ScReason_TeamWin:
		{
			DbSurvivals(client);
			CPrintToChat(client, "%t", "#TF_PH_AlterScore_TeamWin", sc);
			DbInt(client, "wins", 1);
			
			if (GetClientTeam(client) == TEAM_PROP && IsPlayerAlive(client))
			{
				char model[PLATFORM_MAX_PATH];
				PropHuntRedux_GetPropModel(client, model, sizeof(model));
				DbProp(model, "survivals", 1);
			}
		}
		
		case ScReason_Time:
		{
			CPrintToChat(client, "%t", "#TF_PH_AlterScore_TimeAward", sc);
		}
		
		case ScReason_TeamLose:
		{
			CPrintToChat(client, "%t", "#TF_PH_AlterScore_TeamLose", sc*-1);
			DbInt(client, "losses", 1);
		}
	}
	DbInt(client, "points", sc);
}

// MENU HANDLING

public int MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

// TIMERS

public Action Timer_UpdateServerScore(Handle timer)
{
	char query[384];
	
	Format(query, sizeof(query), "UPDATE servers SET points = %d, time = %d WHERE ip = '%s'", g_ServerPointCount, g_ServerTime, g_ServerIP);
	g_StatsDB.Query(T_ErrorOnly, query);
}

public Action Timer_Score(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_PROP)
		{
			AlterScore(client, Points_Time, ScReason_Time);
		}
	}
}

// SQL

void DbInt(int client, const char[] what, int points, Transaction tx=null)
{
	if (!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}
	
	char escapedSteamid[SQLSteamIdLength];
	g_StatsDB.Escape(g_SteamID[client], escapedSteamid, sizeof(escapedSteamid));
	
	char name[MAX_NAME_LENGTH+1];
	GetClientName(client, name, sizeof(name));
	
	char escapedName[SQLNameLength];
	g_StatsDB.Escape(name, escapedName, sizeof(escapedName));
	
	char query[384];
	Format(query, sizeof(query), "UPDATE players SET %s = %s + %d, name = '%s' WHERE steamdi = '%s'", what, what, points, escapedName, escapedSteamid);
	if (tx == null)
	{
		g_StatsDB.Query(T_ErrorOnly, query);
	}
	else
	{
		tx.AddQuery(query);
	}
	g_ServerPointCount += points;
	g_PointCount[client] += points;
	
#if defined LOGSTATS
	LogMessage("[PH] DbInt [%s]", query);
#endif
}

void DbRound(int team)
{
	if (!DatabaseIntact())
	{
		return;
	}
	
	char query[384];
	
	char map[PLATFORM_MAX_PATH], escapedMap[SQLPathLength];
	GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, map, sizeof(map));
	g_StatsDB.Escape(map, escapedMap, sizeof(escapedMap));
	
	Format(query, sizeof(query), "INSERT INTO rounds (team, server, map) VALUES('%s', '%s', '%s')", team == TEAM_PROP ? "RED" : "BLU", g_ServerIP, escapedMap);
	g_StatsDB.Query(T_ErrorOnly, query);

#if defined LOGSTATS
	LogMessage("[PH] DbRound [%s]", query);
#endif
}

void DbProp(const char[] prop, const char[] what, int points)
{
	if (!DatabaseIntact())
	{
		return;
	}
	
	char query[384], escapedProp[SQLPathLength];
	
	g_StatsDB.Escape(prop, escapedProp, sizeof(escapedProp));
	
	Transaction tx = new Transaction();
	
	Format(query, sizeof(query), "INSERT %s INTO props (name) VALUES('%s')", ignore, escapedProp);
	tx.AddQuery(query);
	
	Format(query, sizeof(query), "UPDATE props SET %s = %s + %d WHERE name = '%s'", what, what, points, escapedProp);
	tx.AddQuery(query);
	
	g_StatsDB.Execute(tx, .onError=Tx_Error);

#if defined LOGSTATS
	LogMessage("[PH] DbProp [%s]", query);
#endif
	
}

public bool DatabaseIntact()
{
	return (g_StatsDB != null);
}

//THREADED QUERY CALLBACKS

public void T_ErrorOnly(Database db, DBResultSet result, const char[] error, any data)
{
	if (result == null)
	{
		LogError("[PH] DATABASE ERROR (error: %s)", error);
		PrintToChatAll("[PH] DATABASE ERROR (error: %s)", error);
	}
}

public void T_DBConnect(Database db, const char[] error, any data)
{
	if (db == null)
	{
		SetFailState("%T: %s", "Could not connect to database", LANG_SERVER, error);
		return;
	}
	
	PrintToServer("Connected successfully.");
	
	g_StatsDB = db;
	
	db.SetCharset("utf8");
	
	char driver[64];
	db.Driver.GetIdentifier(driver, sizeof(driver));

	if (StrEqual(driver, "mysql", false))
	{
		//g_DBType = DBType_MySQL;
		ignore = "IGNORE";
	}
	else if (StrEqual(driver, "sqlite", false))
	{
		//g_DBType = DBType_SQLite;
		ignore = "OR IGNORE";
	}
	else if (StrEqual(driver, "pgsql", false))
	{
		//g_DBType = DBType_PostgreSQL;
		// In Postgres, use a rule to ignore dupes: http://stackoverflow.com/a/6176044/15880
	}
	
	Transaction tx = new Transaction();
	
	char query[384];

	Format(query, sizeof(query), "INSERT %s INTO servers (ip) VALUES('%s')", ignore, g_ServerIP);
	tx.AddQuery(query);
	
	Format(query, sizeof(query), "SELECT points, time FROM servers WHERE ip='%s'", g_ServerIP);
	tx.AddQuery(query);
	
	db.Execute(tx, Tx_GetServerPoints, Tx_Error, _, DBPrio_High);
	
	CreateTimer(120.0, Timer_UpdateServerScore, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void T_Statsme(Database db, DBResultSet result, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client == 0)
	{
		return;
	}
	
	if (result == null || !result.HasResults || result.RowCount < 1 || !result.FetchRow())
	{
		PrintToChatAll("Failed to query (error: %s)", error);
		return;
	}
	
	char name[MAX_NAME_LENGTH+1];
	GetClientName(client, name, sizeof(name));
	
	// "\x04%s is on rank %i with %i score (%i wins and %i losses). Time played %i hours."
	CPrintToChatAll("\x04%t", "#TF_PH_Stats_StatsMe", name, result.FetchInt(3), result.FetchInt(0), result.FetchInt(1), 
		result.FetchInt(2), RoundFloat(float(result.FetchInt(4)) / SecondsPerHour));
}

public void T_Rank(Database db, DBResultSet result, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client == 0)
	{
		return;
	}
	
	if (result == null || !result.HasResults || result.RowCount < 1 || !result.FetchRow())
	{
		PrintToChatAll("Failed to query (error: %s)", error);
		return;
	}
	
	Menu smenu = new Menu(MenuHandler);
	
	char buffer[255];
	char winloss[10];
	
	smenu.Pagination = MENU_NO_PAGINATION;
	smenu.SetTitle("%T", "#TF_PH_Stats_PersonalHeader", client);
	
	Format(buffer, sizeof(buffer), "%T", "#TF_PH_Stats_PersonalRank", client, result.FetchInt(3));
	smenu.AddItem("#TF_PH_Stats_PersonalRank", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%T", "#TF_PH_Stats_PersonalWins", client, result.FetchInt(1));
	smenu.AddItem("#TF_PH_Stats_PersonalWins", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%T", "#TF_PH_Stats_PersonalLosses", client, result.FetchInt(2));
	smenu.AddItem("#TF_PH_Stats_PersonalLosses", buffer, ITEMDRAW_DISABLED);
	
	Format(winloss, sizeof(winloss), "%.2f", float(result.FetchInt(1)) / float(result.FetchInt(2)));
	Format(buffer, sizeof(buffer), "%T", "#TF_PH_Stats_PersonalWinLoss", client, winloss);
	smenu.AddItem("#TF_PH_Stats_PersonalWinLoss", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%T", "#TF_PH_Stats_PersonalScore", client, result.FetchInt(0));
	smenu.AddItem("#TF_PH_Stats_PersonalScore", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%T", "#TF_PH_Stats_PersonalTime", client, RoundFloat(float(result.FetchInt(4)) / SecondsPerHour));
	smenu.AddItem("#TF_PH_Stats_PersonalTime", buffer, ITEMDRAW_DISABLED);

	smenu.Display(client, MENU_TIME_FOREVER);
}

public void T_Top10(Database db, DBResultSet result, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client == 0)
	{
		return;
	}
	
	if (result == null || !result.HasResults)
	{
		PrintToChatAll("Failed to query (error: %s)", error);
		return;
	}
	
	Menu smenu = new Menu(MenuHandler);
	// Top 10 needs pagination
	//smenu.Pagination = MENU_NO_PAGINATION;
	smenu.SetTitle("%T", "#TF_PH_Stats_Top10", client);
	
	char buffer[256];
	while (result.FetchRow())
	{
		char name[MAX_NAME_LENGTH+1];
		result.FetchString(0, name, sizeof(name));
		
		Format(buffer, sizeof(buffer), "(%i) %s", result.FetchInt(1));
		smenu.AddItem(buffer, buffer, ITEMDRAW_DISABLED);
	}
	
	smenu.Display(client, MENU_TIME_FOREVER);
}

// THREADED TRANSACTION CALLBACKS

public void Tx_Error(Database db, any data, int numQueries, const char[] error, int failindex, any[] queryData)
{
	LogError("[PH] DATABASE ERROR (error: %s)", error);
	PrintToChatAll("DATABASE ERROR (error: %s)", error);
}

public void Tx_GetServerPoints(Database db, any data, int numQueriest, DBResultSet[] results, any[] queryData)
{
	if (results[TransactionData] == null || results[TransactionData].RowCount < 1 || !results[TransactionData].FetchRow())
	{
		return;
	}
	
	g_ServerPointCount = results[TransactionData].FetchInt(0);
	g_ServerTime = results[TransactionData].FetchInt(1);
}

public void Tx_PlayerConnect(Database db, any userid, int numQueries, DBResultSet[] results, any[] queryData)
{
	int client = GetClientOfUserId(userid);
	if (client == 0 || results[TransactionData] == null || results[TransactionData].RowCount < 1 || !results[TransactionData].FetchRow())
	{
		return;
	}
	
	g_PointCount[client] = results[TransactionData].FetchInt(0);
}

//STOCK FUNCTIONS

void Stats_Init()
{
	// DB Connect logic here
	if (!SQL_CheckConfig(DATABASE))
	{
		SetFailState("No database configuration for %s", DATABASE);
	}
	
	PrintToServer("Connecting to PropHunt database...");
	
	Database.Connect(T_DBConnect, DATABASE);
}

// EXTERNAL CALLBACKS

// Add s to the game description
public Action PropHuntRedux_UpdateGameDescription(char[] description, int maxlength)
{
	StrCat(description, maxlength, "s");
	return Plugin_Changed;
}


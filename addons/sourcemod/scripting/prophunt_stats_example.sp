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
#include <morecolors>
#pragma semicolon 1
#pragma newdecls required

#define VERSION "1.0.0"

#define DATABASE "prophuntstats"

//#define LOGSTATS 1

const int SQLNameLength = MAX_NAME_LENGTH*2+1;
const int Steam2IdLength = 20; // STEAM_0:0:1234567890 <-- this is 1 larger than currently needed, but just to make sure...

// How many points are awarded for each action?
const int DefaultPoints_Killer = 2;
const int DefaultPoints_Assister = 1;
const int DefaultPoints_Victim = -1;

char ignore[16];

ConVar g_Cvar_Enabled;

Database g_StatsDB;
Handle g_hScoreTimer;

ArrayList g_hUsersCreating;

bool isPropHuntRound = false;

int g_ServerPointCount;
int g_PointCount[MAXPLAYERS+1];
int g_ClientTime[MAXPLAYERS+1];
int g_ServerTime;

char g_ServerIP[32];
char g_ServerHostname[128];
int g_ServerPort;

enum DBType
{
	DBType_Unknown,
	DBType_MySQL,
	DBType_SQLite,
	DBType_PostgreSQL
}

DBType g_DBType = DBType_Unknown;

public Plugin myinfo = {
	name			= "PropHunt Stats Example",
	author			= "Powerlord",
	description		= "Example on how to do PropHunt Stats Stuff using a DB connection",
	version			= VERSION,
	url				= ""
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("prophunt.phrases");
	
	CreateConVar("prophunt_stats_example_version", VERSION, "PropHunt Stats Example version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	g_Cvar_Enabled = CreateConVar("prophunt_stats_example_enable", "1", "Enable PropHunt Stats Example?", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundWin);
	HookEvent("player_death", Event_PlayerDeath);
	
	RegConsoleCmd("rank", Cmd_Rank);
	RegConsoleCmd("statsme", Cmd_StatsMe);
	RegConsoleCmd("top10", Cmd_Top10);
	RegConsoleCmd("stats", Cmd_Stats);
	
	DBConnect();
	
	g_hUsersCreating = new ArrayList(ByteCountToCells(Steam2IdLength + 1));
	
	FindConVar("hostname").GetString(g_ServerHostname, sizeof(g_ServerHostname));
	FindConVar("ip").GetString(g_ServerIP, sizeof(g_ServerIP));
	g_ServerPort = FindConVar("hostport").IntValue;
}

void DBConnect()
{
	// DB Connect logic here
	if (!SQL_CheckConfig(DATABASE))
	{
		SetFailState("No database configuration for %s", DATABASE);
	}
	
	PrintToServer("Connecting to PropHunt database...");
	
	Database.Connect(DBFinishConnect, DATABASE);
}

public void DBFinishConnect(Database db, const char[] error, any data)
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
		g_DBType = DBType_MySQL;
		ignore = "IGNORE";
	}
	else if (StrEqual(driver, "sqlite", false))
	{
		g_DBType = DBType_SQLite;
		ignore = "OR IGNORE";
	}
	else if (StrEqual(driver, "pgsql", false))
	{
		g_DBType = DBType_PostgreSQL;
	}
	
	Transaction tx = new Transaction();
	
	char query[384];

	int escapedIpLength = strlen(g_ServerIP)*2+1;
	char[] escapedIp = new char[escapedIpLength];
	db.Escape(g_ServerIP, escapedIp, escapedIpLength);
	
	Format(query, sizeof(query), "INSERT %s INTO servers (ip) VALUES('%s')", ignore, escapedIp);
	tx.AddQuery(query);
	
	Format(query, sizeof(query), "SELECT points, time FROM servers WHERE ip='%s'", escapedIp);
	tx.AddQuery(query);
	
	db.Execute(tx, GetServerPointsCallback, TxErrorCallback, _, DBPrio_High);
	
	CreateTimer(120.0, Timer_UpdateServerScore, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
}

public void OnPluginEnd()
{
	delete g_StatsDB;
}

public void OnMapStart()
{
	// assume false until round start
	isPropHuntRound = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	char steamid[Steam2IdLength+1];
	char name[MAX_NAME_LENGTH+1];
	
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
	{
		LogMessage("Steam ID lookup failed for clent %d (\"%N\")", client, client);
		return;
	}
	
	if (g_hUsersCreating.FindString(steamid) == -1)
	{
		int escapedSteamidLength = strlen(steamid)*2+1;
		char[] escapedSteamid = new char[escapedSteamidLength];
		g_StatsDB.Escape(steamid, escapedSteamid, escapedSteamidLength);
		
		int escapedNameLength = strlen(name)*2+1;
		char[] escapedName = new char[escapedNameLength];
		g_StatsDB.Escape(name, escapedName, escapedNameLength);
		
		int userId = GetClientUserId(client);
		
		DataPack data = CreateDataPack();
		data.WriteCell(userId);
		data.WriteString(escapedSteamid);
	
		char query[256];
		Format(query, sizeof(query), "SELECT steamid FROM players WHERE steamid = '%s'", escapedSteamid);
		g_StatsDB.Query(Query_DoesUserExist, query, data, DBPrio_High);
	}
}

public void Query_DoesUserExist(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		LogError("Database error during user lookup: %s", error);
		delete data;
		return;
	}
	
	data.Reset();
	
	int userid = data.ReadCell();
	int client = GetClientOfUserId(userid);
		
	// Check if client disconnected
	if (client == 0)
	{
		delete data;
		return;
	}
	
	char steamid[Steam2IdLength+1];
	data.ReadString(steamid, sizeof(steamid));
	
	if (results.RowCount == 0)
	{
		if (g_hUsersCreating.FindString(steamid) != -1)
		{
			delete data;
			
			return;
		}
		
		int escapedSteamidLength = strlen(steamid)*2+1;
		char[] escapedSteamid = new char[escapedSteamidLength];
		db.Escape(steamid, escapedSteamid, escapedSteamidLength);
		
		char name[MAX_NAME_LENGTH+1];
		GetClientName(client, name, sizeof(name));
		
		int escapedNameLength = strlen(name)*2+1;
		char[] escapedName = new char[escapedNameLength];
		db.Escape(name, escapedName, escapedNameLength);

		int time = GetTime();
		char query[384];
		
		switch (g_DBType)
		{
			case DBType_MySQL:
			{
				Format(query, sizeof(query), "INSERT IGNORE INTO players (steamid, name, created_on)", escapedSteamid, escapedName, time);
			}
			
			case DBType_SQLite:
			{
				Format(query, sizeof(query), "INSERT OR IGNORE INTO players (steamid, name, created_on)", escapedSteamid, escapedName, time);
				
			}
			
			default:
			{
				// In Postgres, use a rule to ignore dupes: http://stackoverflow.com/a/6176044/15880
				Format(query, sizeof(query), "INSERT INTO players (steamid, name, created_on)", escapedSteamid, escapedName, time);
			}
			
		}
		
		db.Query(Query_CreateUser, query, data, DBPrio_High);
		
		g_hUsersCreating.PushString(steamid);
	}
	
}

public void Query_CreateUser(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		LogError("Database error during user creation: %s", error);
		return;
	}

	data.Reset();
	
	data.ReadCell(); // We don't want the userid this time
	
	char steamid[Steam2IdLength+1];
	data.ReadString(steamid, sizeof(steamid));
	
	int pos = g_hUsersCreating.FindString(steamid);
	if (pos > -1)
	{
		g_hUsersCreating.Erase(pos);
	}
	
	delete data;
}

public void OnClientDisconnect_Post(int client)
{
	
}

public Action Cmd_Rank(int client, int args)
{
	if (client == 0)
	{
		CReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	char steamid[Steam2IdLength+1];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
	{
		CReplyToCommand(client, "%t", "Target is not in game");
		return Plugin_Handled;
	}
	
	int escapedSteamidLength = strlen(steamid)*2+1;
	char[] escapedSteamid = new char[escapedSteamidLength];
	g_StatsDB.Escape(steamid, escapedSteamid, escapedSteamidLength);
	
	int userId = GetClientUserId(client);
	
	// This query probably works in MySQL, but likely not in SQLite
	char query[392];
	Format(query, sizeof(query), "SELECT points, wins, losses, a.rank, time FROM players, (SELECT COUNT(*)+1 as rank FROM players WHERE points > (SELECT points FROM players WHERE steamid = '%s')) WHERE steamid = '%s'");
	
	// Write code to actually do query
	return Plugin_Handled;
}

public Action Cmd_StatsMe(int client, int args)
{
	//TODO
}

public Action Cmd_Top10(int client, int args)
{
	//TODO
}

public Action Cmd_Stats(int client, int args)
{
	//TODO
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	isPropHuntRound = PropHuntRedux_IsRunning(); // This can change every round
	
	if (!g_Cvar_Enabled.BoolValue || !isPropHuntRound)
	{
		return;
	}
	
	g_hScoreTimer = CreateTimer(55.0, Timer_Score, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Cvar_Enabled.BoolValue || !isPropHuntRound)
	{
		return;
	}
	
	isPropHuntRound = false;

	delete g_hScoreTimer;
	
	int winner = event.GetInt("team");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
		{
			continue;
		}
		
		int team = GetClientTeam(client);
		
		if (team == winner) // either props or hunters
		{
			// DB logic to add 3 points
		}
		else if (team > view_as<int>(TFTeam_Spectator)) // either props or hunters
		{
			// DB logic to subtract 1 point
		}
	}
	
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	// Db logic to record map and team win
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_Cvar_Enabled.BoolValue || !isPropHuntRound)
	{
		return;
	}
	
	// PropHunt usually doesn't allow Spies, but just in case
	if (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return;
	}

	int victim, killer, assister;
	int victimPoints = DefaultPoints_Victim;
	int killerPoints = DefaultPoints_Killer;
	int assisterPoints = DefaultPoints_Assister;
	
	int victimId = event.GetInt("userid");
	int killerId = event.GetInt("attacker");
	int assisterId = event.GetInt("assister");
	int weaponID = event.GetInt("weapon");
	
	char weapon[255];
	event.GetString("weapon_logclassname", weapon, sizeof(weapon));
	
	if (victimId > 0)
		victim = GetClientOfUserId(victimId);
		
	if (killerId > 0)
		killer = GetClientOfUserId(killerId);
		
	if (assisterId > 0)
		assister = GetClientOfUserId(assisterId);

	// if victim or killer are non-players, don't process
	if (victim < 0 || victim > MaxClients || killer < 0 || killer > MaxClients)
	{
		return;
	}
	
	char killerName[MAX_NAME_LENGTH+1];
	GetClientName(killer, killerName, sizeof(killerName));
		
	char victimName[MAX_NAME_LENGTH+1];
	GetClientName(victim, victimName, sizeof(victimName));
	
	// This algorithm has corrected a long-standing bug in PropHunt stats where the float conversion was done after
	// int math had already taken place
	killerPoints = RoundFloat(float(g_PointCount[victim]) / float(g_PointCount[killer]));
	
	// Point caps
	if (killerPoints < 2)
	{
		killerPoints = 2;
	}
	else if (killerPoints > 8)
	{
		killerPoints = 8;
	}
	
	//Assister point caps
	if (assister > 0)
	{
		assisterPoints = RoundFloat(float(g_PointCount[victim]) / float(g_PointCount[assister]) / 2.0);
	}
	
	// victim point caps
	if (killerPoints == 2)
	{
		victimPoints = -1;
	}
	else
	{
		victimPoints = 0 - RoundFloat(killerPoints * 0.5);
	}
	
	Transaction tx = new Transaction();

	if (IsClientInGame(victim))
	{
		if (GetClientTeam(victim) == TEAM_PROP)
		{
			char model[PLATFORM_MAX_PATH];
			PropHuntRedux_GetPropModel(victim, model, sizeof(model));
			DbProp(model, "death", 1);
		}
		CPrintToChat(victim, "%t", "#TF_PH_AlterScore_Death", killerName, victimPoints*-1);
		DbInt(victim, "points", victimPoints);
	}
	
	
	
	
	// DB logic to add points to killer here

	// DB logic to add points to assister here
}

public Action Timer_Score(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_PROP)
		{
			// DB Logic to add 2 points
		}
	}
}

public void PHCallback(Database db, DBResultSet results, const char[] error, any data)
{
	// Do something if we got a SQL Error.
}

void DbProp(const char[] prop, const char[] what, int points)
{
	char query[384];
	int escapedPropLength = strlen(prop)*2+1;
	char[] escapedProp = new char[escapedPropLength];
	g_StatsDB.Escape(prop, escapedProp, escapedPropLength);
	
	Format(query, sizeof(query), "INSERT IGNORE INTO props (name) VALUES('%s')", escapedProp);
	
	DataPack data = new DataPack();
	data.WriteString(escapedProp);
	data.WriteString(what);
	data.WriteCell(points);
	data.Reset();
	
	// High priority 
	g_StatsDB.Query(InsertPropCallback, query, data, DBPrio_High);
}

public void InsertPropCallback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		// Insert failed?
		delete data;
		return;
	}
	
	char escapedProp[PLATFORM_MAX_PATH];
	data.ReadString(escapedProp, sizeof(escapedProp));
	
	char what[64];
	data.ReadString(what, sizeof(what));
	
	int points = data.ReadCell();
	
	char query[384];
	Format(query, sizeof(query), "UPDATE props SET %s = %s + %d WHERE name='%s'", what, what, points, escapedProp);
	db.Query(ErrorOnlyCallback, query);
	
#if defined LOGSTATS
	LogMessage("[PH] DbProp [%s]", query);
#endif
	
	delete data;
}

public void ErrorOnlyCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[PH] DATABASE ERROR (error: %s)", error);
		CPrintToChatAll("[PH] DATABASE ERROR (error: %s)", error);
	}
}

public void TxErrorCallback(Database db, any data, int numQueries, const char[] error, int failIndex, any[]queryData)
{
	LogError("[PH] DATABASE ERROR (error: %s)", error);
	CPrintToChatAll("[PH] DATABASE ERROR (error: %s)", error);
}

void DbInt(int client, const char[] what, int points, Transaction tx=null)
{
	if (!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}
	
	char steamid[Steam2IdLength+1];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
	{
		return;
	}

	int escapedSteamidLength = strlen(steamid)*2+1;
	char[] escapedSteamid = new char[escapedSteamidLength];
	g_StatsDB.Escape(steamid, escapedSteamid, escapedSteamidLength);
	
	char name[MAX_NAME_LENGTH+1];
	GetClientName(client, name, sizeof(name));
	
	int escapedNameLength = strlen(name)*2+1;
	char[] escapedName = new char[escapedNameLength];
	g_StatsDB.Escape(name, escapedName, escapedNameLength);
	
	char query[384];
	Format(query, sizeof(query), "UPDATE players SET %s = %s + %d, name = '%s' WHERE steamdi = '%s'", what, what, points, escapedName, escapedSteamid);
	if (tx == null)
	{
		g_StatsDB.Query(ErrorOnlyCallback, query);
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

public bool DatabaseIntact()
{
	return (g_StatsDB != null);
}

// Add s to the game description
public Action UpdateGameDescription(char description[128])
{
	StrCat(description, sizeof(description), "s");
	return Plugin_Changed;
}
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
#pragma semicolon 1

#define VERSION "1.0.0"

#define DATABASE "prophuntstats"

const SQLNameLength = MAX_NAME_LENGTH*2+1;
const Steam2IdLength = 20; // STEAM_0:0:1234567890 <-- this is 1 larger than currently needed, but just to make sure...

new Handle:g_Cvar_Enabled;

new Handle:g_hDb;
new Handle:g_hScoreTimer;

new Handle:g_hUsersCreating;

new bool:isPropHuntRound = false;

new g_PointCount[MAXPLAYERS+1];
new g_ClientTime[MAXPLAYERS+1];

enum DBType
{
	DBType_Unknown,
	DBType_MySQL,
	DBType_SQLite,
	DBType_PostgreSQL
}

new DBType:g_DBType;

public Plugin:myinfo = {
	name			= "PropHunt Stats Example",
	author			= "Powerlord",
	description		= "Example on how to do PropHunt Stats Stuff using a DB connection",
	version			= VERSION,
	url				= ""
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("prophunt.phrases");
	
	CreateConVar("prophunt_stats_example_version", VERSION, "PropHunt Stats Example version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	g_Cvar_Enabled = CreateConVar("prophunt_stats_example_enable", "1", "Enable PropHunt Stats Example?", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundWin);
	HookEvent("player_death", Event_PlayerDeath);
	
	RegConsoleCmd("rank", Cmd_Rank);
	RegConsoleCmd("statsme", Cmd_StatsMe);
	RegConsoleCmd("top10", Cmd_Top10);
	RegConsoleCmd("stats", Cmd_Stats);
	
	DBConnect();
	
	g_hUsersCreating = CreateArray(ByteCountToCells(Steam2IdLength + 1));
}

DBConnect()
{
	// DB Connect logic here
	new String:error[255];
	
	if (!SQL_CheckConfig(DATABASE))
	{
		SetFailState("No database configuration for %s", DATABASE);
	}
	
	// We want a persistent connection as we continually do updates (minimum of every 55 seconds)
	g_hDb = SQL_Connect(DATABASE, true, error, sizeof(error));
	
	if (g_hDb == INVALID_HANDLE)
	{
		LogError("%T: %s", "Could not connect to database", LANG_SERVER, error);
		return;
	}
	
	SQL_SetCharset(g_hDb, "utf8");
	
	new String:driver[64];
	SQL_ReadDriver(g_hDb, driver, sizeof(driver));
	
	if (StrEqual(driver, "mysql", false))
	{
		g_DBType = DBType_MySQL;
	}
	else if (StrEqual(driver, "sqlite", false))
	{
		g_DBType = DBType_SQLite;
	}
	else if (StrEqual(driver, "pgsql", false))
	{
		g_DBType = DBType_PostgreSQL;
	}
}

public OnPluginEnd()
{
	CloseHandle(g_hDb);
}

public OnMapStart()
{
	// assume false until round start
	isPropHuntRound = false;
}

public OnClientPostAdminCheck(client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
	{
		return;
	}
	
	new String:steamid[Steam2IdLength+1];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
	{
		return;
	}
	
	if (FindStringInArray(g_hUsersCreating, steamid) != -1)
	{
		new escapedSteamidLength = strlen(steamid)*2+1;
		new String:escapedSteamid[escapedSteamidLength];
		SQL_EscapeString(g_hDb, steamid, escapedSteamid, escapedSteamidLength);
		
		new userId = GetClientUserId(client);
		
		new Handle:data = CreateDataPack();
		WritePackCell(data, userId);
		WritePackString(data, escapedSteamid);
	
		new String:query[256];
		Format(query, sizeof(query), "SELECT steamid FROM players WHERE steamid = '%s'", escapedSteamid);
		SQL_TQuery(g_hDb, Query_DoesUserExist, query, data, DBPrio_High);
	}
}

public Query_DoesUserExist(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Database error during user lookup: %s", error);
		CloseHandle(data);
		return;
	}
	
	ResetPack(data);
	
	new userid = ReadPackCell(data);
	new client = GetClientOfUserId(userid);
		
	// Check if client disconnected
	if (client == 0)
	{
		CloseHandle(data);
		return;
	}
	
	new String:steamid[Steam2IdLength+1];
	ReadPackString(data, steamid, sizeof(steamid));
	
	if (!SQL_GetRowCount(hndl))
	{
		if (FindStringInArray(g_hUsersCreating, steamid) != -1)
		{
			CloseHandle(data);
			
			return;
		}
		
		new escapedSteamidLength = strlen(steamid)*2+1;
		new String:escapedSteamid[escapedSteamidLength];
		SQL_EscapeString(g_hDb, steamid, escapedSteamid, escapedSteamidLength);
		
		new String:name[MAX_NAME_LENGTH+1];
		GetClientName(client, name, sizeof(name));
		
		new escapedNameLength = strlen(name)*2+1;
		new String:escapedName[escapedNameLength];
		SQL_EscapeString(g_hDb, name, escapedName, escapedNameLength);

		new time = GetTime();
		new String:query[384];
		
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
		
		SQL_TQuery(g_hDb, Query_CreateUser, query, data, DBPrio_High);
		
		PushArrayString(g_hUsersCreating, steamid);
	}
	
}

public Query_CreateUser(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Database error during user creation: %s", error);
		return;
	}
	
	ResetPack(data);
	
	ReadPackCell(data); // We don't want the userid this time
	
	new String:steamid[Steam2IdLength+1];
	ReadPackString(data, steamid, sizeof(steamid));
	
	new pos = FindStringInArray(g_hUsersCreating, steamid);
	if (pos > -1)
	{
		RemoveFromArray(g_hUsersCreating, pos);
	}
	
	CloseHandle(data);
}

public OnClientDisconnect_Post(client)
{
	
}

public Action:Cmd_Rank(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	new String:steamid[Steam2IdLength+1];
	if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
	{
		ReplyToCommand(client, "%t", "Target is not in game");
		return Plugin_Handled;
	}
	
	new escapedSteamidLength = strlen(steamid)*2+1;
	new String:escapedSteamid[escapedSteamidLength];
	SQL_EscapeString(g_hDb, steamid, escapedSteamid, escapedSteamidLength);
	
	new userId = GetClientUserId(client);
	
	// This query probably works in MySQL, but likely not in SQLite
	new String:query[392];
	Format(query, sizeof(query), "SELECT points, wins, losses, a.rank, time FROM players, (SELECT COUNT(*)+1 as rank FROM players WHERE points > (SELECT points FROM players WHERE steamid = '%s')) WHERE steamid = '%s'");
	
	return Plugin_Handled;
}

public Action:Cmd_StatsMe(client, args)
{
}

public Action:Cmd_Top10(client, args)
{
}

public Action:Cmd_Stats(client, args)
{
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	isPropHuntRound = PropHuntRedux_IsRunning(); // This can change every round
	
	if (!GetConVarBool(g_Cvar_Enabled) || !isPropHuntRound)
	{
		return;
	}
	
	g_hScoreTimer = CreateTimer(55.0, Timer_Score, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Event_RoundWin(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_Cvar_Enabled) || !isPropHuntRound)
	{
		return;
	}
	
	isPropHuntRound = false;

	CloseHandle(g_hScoreTimer);
	
	new winner = GetEventInt(event, "team");
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
		{
			continue;
		}
		
		new team = GetClientTeam(client);
		
		if (team == winner) // either props or hunters
		{
			// DB logic to add 3 points
		}
		else if (team > _:TFTeam_Spectator) // either props or hunters
		{
			// DB logic to subtract 1 point
		}
	}
	
	new String:map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	// Db logic to record map and team win
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_Cvar_Enabled) || !isPropHuntRound)
	{
		return;
	}
	
	// PropHunt usually doesn't allow Spies, but just in case
	if (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return;
	}
	
	new clientID = GetEventInt(event, "userid");
	new attackerID = GetEventInt(event, "attacker");
	new assisterID = GetEventInt(event, "assister");
	new weaponID = GetEventInt(event, "weapon");
	new String:weapon[255];
	GetEventString(event, "weapon_logclassname", weapon, sizeof(weapon));
	
	// DB logic to store the kill goes here
	
	// DB logic to add points to killer here

	// DB logic to add points to assister here
}

public Action:Timer_Score(Handle:Timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_PROP)
		{
			// DB Logic to add 2 points
		}
	}
}

public PHCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	// Do something if we got a SQL Error.
}
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

new Handle:g_Cvar_Enabled;

new Handle:g_hDb;
new Handle:g_hScoreTimer;

new bool:isPropHuntRound = false;

public Plugin:myinfo = {
	name			= "PropHunt Stats Example",
	author			= "Powerlord",
	description		= "Example on how to do PropHunt Stats Stuff using a DB connection",
	version			= VERSION,
	url				= ""
};

public OnPluginStart()
{
	CreateConVar("prophunt_stats_example_version", VERSION, "PropHunt Stats Example version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	g_Cvar_Enabled = CreateConVar("prophunt_stats_example_enable", "1", "Enable PropHunt Stats Example?", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundWin);
	HookEvent("player_death", Event_PlayerDeath);
	
	// DB Connect logic here
	new String:error[255];
	g_hDb = SQL_Connect("prophuntstats", true, error, sizeof(error));
	
	if (g_hDb == INVALID_HANDLE)
	{
		SetFailState("Error connecting to database: %s", error);
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
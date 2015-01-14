/**
 * vim: set ts=4 :
 * =============================================================================
 * PropHunt Stats Ajax Example
 * Example on how to do PropHunt Stats Stuff using REST calls
 *
 * This plugin is used to exhibit more control over the stats system.
 * The remote web application can do heuristics to tell if a server is being
 * used to cheat at stats.
 * 
 * It also makes it so the central stats system controls the point values for
 * actions as they are no longer sent.
 * 
 * It forces Steam 2 IDs for consistency.  This way, you don't have to deal
 * with Valve suddenly changing the Steam ID types (like they did last year).
 * 
 * It's a good idea if the stats system ignores any kills on STEAM_ID_BOT
 * or STEAM_ID_LAN for example.
 * 
 * PropHunt Stats Ajax Example (C)2015 Powerlord (Ross Bemrose).
 * All rights reserved.
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
#include <steamtools>
#include <tf2_stocks>
#include <tf2>
#include <morecolors>
#pragma semicolon 1

#define VERSION "1.0.0"

#define DATABASE "prophuntstats"

new const String:server[] = "https://www.example.com/prophunt/stats";
const SQLNameLength = MAX_NAME_LENGTH*2+1;
const Steam2IdLength = 20; // STEAM_0:0:1234567890 <-- this is 1 larger than currently needed, but just to make sure...

new Handle:g_Cvar_Enabled;
new Handle:g_Cvar_ServerID;

new Handle:g_hScoreTimer;

new bool:isPropHuntRound = false;

new String:g_sServerID[256];

new String:g_sSteam2IDs[MAXPLAYERS+1][Steam2IdLength+1];

public Plugin:myinfo = {
	name			= "PropHunt Stats REST Example",
	author			= "Powerlord",
	description		= "Example on how to do PropHunt Stats Stuff using REST endpoints",
	version			= VERSION,
	url				= ""
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("prophunt.phrases");
	
	CreateConVar("prophunt_stats_example_ajax_version", VERSION, "PropHunt Stats Example version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	g_Cvar_Enabled = CreateConVar("prophunt_stats_example_ajax_enable", "1", "Enable PropHunt Stats Example?", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_Cvar_ServerID = CreateConVar("prophunt_stats_example_ajax_serverid", "", "Server ID for PropHunt Stats", FCVAR_PLUGIN|FCVAR_PROTECTED);
	
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundWin);
	HookEvent("player_death", Event_PlayerDeath);
	
	RegConsoleCmd("rank", Cmd_Rank);
	RegConsoleCmd("statsme", Cmd_StatsMe);
	RegConsoleCmd("top10", Cmd_Top10);
	RegConsoleCmd("stats", Cmd_Stats);
}

public OnAllPluginsLoaded()
{
	// We do this to record the server's current IP address
	new String:url[255];
	Format(url, sizeof(url), "%s/serverStart", server);
	
	// PropHunt Stats methods are not idempotent and thus should use POST
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);

	// All requests require a server ID
	Steam_SetHTTPRequestGetOrPostParameter(request, "serverid", g_sServerID);
	Steam_SendHTTPRequest(request, Response_ErrorOnly);
	
}

public OnMapStart()
{
	// assume false until round start
	isPropHuntRound = false;
}

public OnConfigsExecuted()
{
	GetConVarString(g_Cvar_ServerID, g_sServerID, sizeof(g_sServerID));
}

public OnClientAuthorized(client, const String:auth[])
{
	if (!IsClientConnected(client) || IsFakeClient(client))
	{
		return;
	}
	
	// Ignore auth and use the Steam2 ID
	if (!GetClientAuthId(client, AuthId_Steam2, g_sSteam2IDs[client], sizeof(g_sSteam2IDs[])))
	{
		return;
	}
	
	new String:url[255];
	Format(url, sizeof(url), "%s/connected", server);
	
	// PropHunt Stats methods are not idempotent and thus should use POST
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
	Steam_SetHTTPRequestGetOrPostParameter(request, "serverid", g_sServerID);
	//	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	Steam_SetHTTPRequestGetOrPostParameter(request, "steamid", g_sSteam2IDs[client]);
	Steam_PrioritizeHTTPRequest(request); // Connected needs to be high priority because it may need to create the stats user on the DB side
	Steam_SendHTTPRequest(request, Response_ErrorOnly);
}

public OnClientDisconnect(client)
{
	new String:url[255];
	Format(url, sizeof(url), "%s/disconnected", server);
	
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
	Steam_SetHTTPRequestGetOrPostParameter(request, "serverid", g_sServerID);
	//	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	Steam_SetHTTPRequestGetOrPostParameter(request, "steamid", g_sSteam2IDs[client]);
	Steam_SendHTTPRequest(request, Response_ErrorOnly);
	
	g_sSteam2IDs[client][0] = '\0';
}

public Response_ErrorOnly(HTTPRequestHandle:HTTPRequest, bool:requestSuccessful, HTTPStatusCode:statusCode)
{
	if (!requestSuccessful)
	{
		LogError("Stats server returned error.  Status code: %d", statusCode);
		return;
	}
}

public Action:Cmd_Rank(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	
	if (g_sSteam2IDs[client][0] == '\0')
	{
		ReplyToCommand(client, "%t", "Target is not in game");
		return Plugin_Handled;
	}

	// Do REST call here
	
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
			// REST logic to add 3 points
		}
		else if (team > _:TFTeam_Spectator) // either props or hunters
		{
			// REST logic to subtract 1 point
		}
	}
	
	new String:map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	// REST logic to record map and team win
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
	
	new client = GetClientOfUserId(clientID);
	new attacker;
	if (attackerID > 0)
	{
		attacker = GetClientOfUserId(attackerID);
	}
	
	new assister;
	if (assisterID > 0)
	{
		assister = GetClientOfUserId(assisterID);
	}
	
	new String:url[255];
	Format(url, sizeof(url), "%s/playerkill", server);
	
	new String:clientName[MAX_NAME_LENGTH+1];
	new String:attackerName[MAX_NAME_LENGTH+1];
	new String:assisterName[MAX_NAME_LENGTH+1];
	
	GetClientName(client, clientName, sizeof(clientName));
		
	// Note that in the original, this method had no less than 3 DB calls in it.  However, I want to do just one REST call.

	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
	Steam_SetHTTPRequestGetOrPostParameter(request, "serverid", g_sServerID);
	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	Steam_SetHTTPRequestGetOrPostParameter(request, "clientSteamId", g_sSteam2IDs[client]);
	if (attacker > 0)
	{
		GetClientName(attacker, attackerName, sizeof(attackerName));
		Steam_SetHTTPRequestGetOrPostParameter(request, "attackerSteamId", g_sSteam2IDs[attacker]);
		new team = GetClientTeam(attacker);
		new String:strTeam[2];
		IntToString(team, strTeam, sizeof(strTeam));

		Steam_SetHTTPRequestGetOrPostParameter(request, "killerTeam", strTeam);
		
	}
	
	if (assister > 0)
	{
		GetClientName(assister, assisterName, sizeof(assisterName));
		Steam_SetHTTPRequestGetOrPostParameter(request, "assisterSteamId", g_sSteam2IDs[assister]);
	}
	
	new weaponIndex = -1;
	
	new String:strWeaponIndex[7];
	
	if (weaponID > MaxClients)
	{
		weaponIndex = GetEntProp(weaponID, Prop_Send, "m_iItemDefinitionIndex");
	}
	
	IntToString(weaponIndex, strWeaponIndex, sizeof(strWeaponIndex));
	
	// Definition index will allow lookup of weapons on remote web server.
	Steam_SetHTTPRequestGetOrPostParameter(request, "weaponDefinitionIndex", strWeaponIndex);
	
	new String:propModel[PLATFORM_MAX_PATH];
	PropHuntRedux_GetPropModel(client, propModel, sizeof(propModel));

	new Handle:data = CreateDataPack();
	
	WritePackCell(data, clientID);
	WritePackCell(data, attackerID);
	WritePackCell(data, assisterID);
	WritePackString(data, clientName);
	WritePackString(data, attackerName);
	WritePackString(data, assisterName);
		
	// TODO Check to see what other fields we're missing.
	Steam_SendHTTPRequest(request, Response_PlayerKilled, data); // different method so we can print score changes
}

public Response_PlayerKilled(HTTPRequestHandle:response, bool:requestSuccessful, HTTPStatusCode:statusCode, any:data)
{
	if (!requestSuccessful)
	{
		LogError("Stats server returned error.  Status code: %d", statusCode);
		return;
	}
	
	ResetPack(data);
	
	new clientID = ReadPackCell(data);
	new attackerID = ReadPackCell(data);
	new assisterID = ReadPackCell(data);
	
	new client = GetClientOfUserId(clientID);
	new attacker;
	
	if (attackerID > 0)
	{
		attacker = GetClientOfUserId(attackerID);
	}
	
	new assister;
	
	if (assisterID > 0)
	{
		assister = GetClientOfUserId(assisterID);
	}

	new String:clientName[MAX_NAME_LENGTH+1];
	new String:attackerName[MAX_NAME_LENGTH+1];
	new String:assisterName[MAX_NAME_LENGTH+1];
	
	ReadPackString(data, clientName, sizeof(clientName));
	ReadPackString(data, attackerName, sizeof(attackerName));
	ReadPackString(data, assisterName, sizeof(assisterName));
	
	new bufferSize = Steam_GetHTTPResponseBodySize(response);
	new String:buffer[bufferSize];
	Steam_GetHTTPResponseBodyData(response, buffer, bufferSize);
	
	new Handle:kvBuffer;
	if (StringToKeyValues(kvBuffer, buffer, "PropHuntKillResponse"))
	{
		new clientPoints = KvGetNum(kvBuffer, "clientPoints", -1);
		new killerPoints = KvGetNum(kvBuffer, "killerPoints", 2);
		new assisterPoints = KvGetNum(kvBuffer, "assisterPoints", 1);
		
		if (client > 0)
			CPrintToChat(client, "%t", "#TF_PH_AlterScore_Death", attackerName, clientPoints*-1);
		
		if (attacker > 0)
			CPrintToChat(attacker, "%t", "#TF_PH_AlterScore_Kill", clientName, killerPoints);
		
		if (assister > 0)
			CPrintToChat(assister, "%t", "#TF_PH_AlterScore_Assist", clientName, assisterPoints);
		
		
		// Do stuff with the keyvalues
	}
}

public Action:Timer_Score(Handle:Timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_PROP)
		{
			new String:url[255];
			Format(url, sizeof(url), "%s/proptimescore", server);
			
			new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
			Steam_SetHTTPRequestGetOrPostParameter(request, "serverid", g_sServerID);
			//	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
			Steam_SetHTTPRequestGetOrPostParameter(request, "steamid", g_sSteam2IDs[client]);
			Steam_SendHTTPRequest(request, Response_ErrorOnly);
		}
	}
}

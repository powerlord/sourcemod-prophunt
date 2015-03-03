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
 * Version: 3.4.0
 */
// PropHunt Redux by Powerlord
//         Based on
//  PropHunt by Darkimmortal
//   - GamingMasters.org -
#if defined _prophunt_redux_included_
  #endinput
#endif
#define _prophunt_redux_included_

// PropHunt Redux 3.4+ series

#include <tf2>

#define TEAM_PROP _:TFTeam_Red
#define TEAM_HUNTER _:TFTeam_Blue

enum ScReason
{
	ScReason_TeamWin = 0,
	ScReason_TeamLose,
	ScReason_Death, // Not used in default scoring, passed as PropHuntRedux_Stats_PlayerKilled instead
	ScReason_Kill, // Not used in default scoring, passed as PropHuntRedux_Stats_PlayerKilled instead
	ScReason_Time,
	ScReason_Friendly // Not used in default scoring, friendly fire has been disabled by default in PH for years.
};

/**
 * Is PropHunt Redux currently running?
 * 
 * This should be valid for teamplay_round_start post-hooks (but possibly not pre-hooks)
 * 
 * @return	true if PropHunt Redux is running, false otherwise
 */
native bool:PropHuntRedux_IsRunning();

/**
 * Is the named map a valid PropHunt map?
 * 
 * @return 	true if yes, false if no
 */
native bool:PropHuntRedux_ValidateMap(const String:map[]);

/**
 * Get the model of a prop player.
 * 
 * @return	true if client is/was a prop and has a model, false otherwise
 */
native bool:PropHuntRedux_GetPropModel(client, String:model[], maxlen);

/**
 * Get the name of the model of a prop player.
 * 
 * Note: Defaults to the server language (likely English)
 * 
 * @return	true if client is/was a prop and has a model, false otherwise
 */
native bool:PropHuntRedux_GetPropModelName(client, String:name[], maxlen, targetClient=LANG_SERVER);

//functag public PropHuntRedux_Stats_Init();
//functag public PropHuntRedux_Stats_Uninit();

//functag public PropHuntRedux_Stats_RoundWin(winner);

// Note that score is no longer passed.  The stats plugin should decide what the score is.
// In classic PH stats, time is 2 points, win is 3 points, lose is -1 point.
// In Redux, time is awarded to props once when Setup ends and then every 55 seconds afterwards until round end.
// This replaces the "awarded every 55 seconds" behavior that happened regardless of what was going on.
//functag public PropHuntRedux_Stats_AlterScore(client, SCReason:reason);

//functag public PropHuntRedux_Stats_PlayerKilled(clientID, attackerID, assisterID, weaponid, const String:weapon[]);

// Note: Not finished, stopped here
// We still need a native to register stuff and possibly more stats functions

//functag public PropHuntRedux_Stats_ClientConnected(client);
//functag public PropHuntRedux_Stats_ClientDisconnected(client);

public SharedPlugin:__pl_prophunt_redux = 
{
	name = "Prophunt Redux",
	file = "prophunt.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_prophunt_redux_SetNTVOptional()
{
	MarkNativeAsOptional("PropHuntRedux_IsRunning");
	MarkNativeAsOptional("PropHuntRedux_ValidateMap");
	MarkNativeAsOptional("PropHuntRedux_GetPropModel");
	MarkNativeAsOptional("PropHuntRedux_GetPropModelName");
}
#endif

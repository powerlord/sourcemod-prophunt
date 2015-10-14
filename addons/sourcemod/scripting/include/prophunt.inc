/**
 * vim: set ts=4 :
 * =============================================================================
 * TF2 PropHunt Redux
 * Hide as a prop from the evil Pyro menace... or hunt down the hidden prop scum
 * 
 * TF2 PropHunt (C)2007-2015 Darkimmortal.  All rights reserved.
 * TF2 PropHunt Redux (C)2013-2015 Powerlord (Ross Bemrose).  All rights reserved.
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
#if defined _prophunt_redux_included_
  #endinput
#endif
#define _prophunt_redux_included_

// PropHunt Redux 4.0+ series

#include <tf2>

#define TEAM_PROP view_as<int>(TFTeam_Red)
#define TEAM_HUNTER view_as<int>(TFTeam_Blue)
#define TEAM_SPECTATOR view_as<int>(TFTeam_Spectator)

/**
 * Is PropHunt Redux currently running?
 * 
 * This should be valid for teamplay_round_start post-hooks (but possibly not pre-hooks)
 * 
 * @return	true if PropHunt Redux is running, false otherwise
 */
native bool PropHuntRedux_IsRunning();

/**
 * Is the named map a valid PropHunt map?
 * 
 * @return 	true if yes, false if no
 */
native bool PropHuntRedux_ValidateMap(const char[] map);

/**
 * Get the model of a prop player.
 * 
 * @return	true if client is/was a prop and has a model, false otherwise
 */
native bool PropHuntRedux_GetPropModel(int client, char[] model, int maxlen);

/**
 * Get the name of the model of a prop player.
 * 
 * Note: Defaults to the server language (likely English)
 * 
 * @return	true if client is/was a prop and has a model, false otherwise
 */
native bool PropHuntRedux_GetPropModelName(int client, char[] name, int maxlen, int targetClient=LANG_SERVER);

/**
 * Retrieve whether we're currently in Last Prop Mode.
 * 
 * @return	true if this is last prop mode, false otherwise.
 */
native bool PropHuntRedux_IsLastPropMode();

/**
 * Callback called when the game description is being updated
 * 
 * Stat plugins can use this to append data to the end of the string.
 * 
 * @param description	The current / updated description.  Maxes out at 128 characters.
 * @return Plugin_Changed if your plugin changed the game description.
 *         Plugin_Continued otherwise.
 */
forward Action PropHuntRedux_UpdateGameDescription(char[] description, int maxlength);

public SharedPlugin __pl_prophunt_redux = 
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
public void __pl_prophunt_redux_SetNTVOptional()
{
	MarkNativeAsOptional("PropHuntRedux_IsRunning");
	MarkNativeAsOptional("PropHuntRedux_ValidateMap");
	MarkNativeAsOptional("PropHuntRedux_GetPropModel");
	MarkNativeAsOptional("PropHuntRedux_GetPropModelName");
	MarkNativeAsOptional("PropHuntRedux_IsLastPropMode");
}
#endif

/**
 * vim: set ts=4 :
 * =============================================================================
 * Opt-in Multimod
 * A Multi-mod plugin that uses explicit support from the game to do voting
 * for game modes.  Can do votes per-round.
 * 
 * Copyright (C) 2013-2014 Ross Bemrose (Powerlord).  All rights reserved.
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
 
#if defined _optin_multimod_included
  #endinput
#endif
#define _optin_multimod_included

#include <sourcemod>

functag public OptInMultiMod_StatusChanged(bool:enabled);

functag public bool:OptInMultiMod_ValidateMap(const String:map[]);

// This is mandatory, due to translations being specific to the plugin that loads them
// Note: This feature may be pulled out before final
functag public OptInMultiMod_GetTranslation(client, String:translation[], maxlength);

native OptInMultiMod_Register(const String:name[], OptInMultiMod_ValidateMap:validateMap, OptInMultiMod_StatusChanged:status, OptInMultiMod_GetTranslation:translator=INVALID_FUNCTION);
native OptInMultiMod_Unregister(const String:name[]);

// You should NEVER require this plugin
public SharedPlugin:__pl_optin_multimod = 
{
	name = "optin_multimod",
	file = "optin_multimod.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_optin_multimod_SetNTVOptional()
{
	MarkNativeAsOptional("OptInMultiMod_Register");
	MarkNativeAsOptional("OptInMultiMod_Unregister");
}
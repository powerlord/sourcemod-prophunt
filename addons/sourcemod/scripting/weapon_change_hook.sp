#include <sourcemod>
#pragma semicolon 1

#include <sdkhooks>

#define VERSION "1.0.0"

new Handle:g_Cvar_Enabled;

public Plugin:myinfo = {
	name			= "Weapon Change Hook",
	author			= "Powerlord",
	description		= "SDKHooks Weapon Change Hook check",
	version			= VERSION,
	url				= ""
};

public OnPluginStart()
{
	CreateConVar("weaponchange_version", VERSION, "Weapon Change Hook version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	g_Cvar_Enabled = CreateConVar("weaponchange_enable", "1", "Enable Weapon Change Hook?", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 1.0);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponChange);
}

public WeaponChange(client, weapon)
{
	if (!g_Cvar_Enabled)
	{
		return;
	}
	
	PrintToChat(client, "Switching to weapon %d", weapon);
}

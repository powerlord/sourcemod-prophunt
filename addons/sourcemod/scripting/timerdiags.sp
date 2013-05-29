#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "Timer Diagnostics",
	author = "Powerlord",
	description = "Diagnostics of team_round_timer entities",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{
	RegAdminCmd("timer", Cmd_TimerStats, ADMFLAG_BAN, "Show timer stats");
	RegAdminCmd("master", Cmd_MasterControl, ADMFLAG_BAN, "Show control point master stats");
}

public Action:Cmd_TimerStats(client, args)
{
	new timer = -1;
	while ((timer = FindEntityByClassname(timer, "team_round_timer")) != -1)
	{
		decl String:name[64];
		GetEntPropString(timer, Prop_Data, "m_iName", name, sizeof(name));
		new bool:bIsPaused = bool:GetEntProp(timer, Prop_Send, "m_bTimerPaused");
		new bool:bIsDisabled = bool:GetEntProp(timer, Prop_Send, "m_bIsDisabled");
		new bool:bShowInHud = bool:GetEntProp(timer, Prop_Send, "m_bShowInHUD");
		new iTimeRemaining = GetEntProp(timer, Prop_Send, "m_nTimerLength");
		
		PrintToChatAll("Timer %d. name: %s, paused: %d, disabled: %d, show in hud: %d, time left: %d", timer, name, bIsPaused, bIsDisabled, bShowInHud, iTimeRemaining);
	}
	return Plugin_Handled;
}

public Action:Cmd_MasterControl(client, args)
{
	new point = -1;
	while ((point = FindEntityByClassname(point, "team_control_point_master")) != -1)
	{
		decl String:name[64];
		GetEntPropString(point, Prop_Data, "m_iName", name, sizeof(name));
		
		new bool:bSwitchTeams = bool:GetEntProp(point, Prop_Data, "m_bSwitchTeamsOnWin");
		new bool:bDisabledByDefault = bool:GetEntProp(point, Prop_Data, "m_bDisabled");
		
		PrintToChatAll("Master %d. name: %s, switch teams: %d, disabled by default: %d", point, name, bSwitchTeams, bDisabledByDefault);
	}
	
	return Plugin_Handled;
}

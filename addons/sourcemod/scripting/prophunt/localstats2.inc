// PropHunt Redux Local Stats by Powerlord
//     - reddit.com/r/RUGC_Midwest -

// Don't use this code yet, it's not finished
/*
 * NOTE: Queries used when connecting to the DB are non-threaded because we want them to complete before
 * any threaded queries would run
 */

#define CURRENT_SCHEMA_VERSION		1
#define SCHEMA_UPGRADE_1			1

#define DATABASE "prophunt_local"
new Handle:g_LocalStatsDb;

LocalStats_Init()
{
	RegConsoleCmd("phrank", Command_localstatsme);
	RegConsoleCmd("phstatsme", Command_localstats);
	RegConsoleCmd("phtop10", Command_localtop10);
	
	decl String:error[255], String:query[392];
	new Handle:db;

	if (!SQL_CheckConfig(DATABASE))
	{
		LogError("[PH] No %s database found in configs/databases.cfg", DATABASE);
		return;
	}
	
	PrintToServer("Connecting to Local PropHunt database...");
	
	db = LocalStats_Connect(error);
	
	if (db != INVALID_HANDLE)
	{
		PrintToServer("Connected successfully.");
	}
	else
	{
		PrintToServer("Connection failed: %s", error);
		return;
	}
	
	RegConsoleCmd("phstats", Command_motdlocal, "Local Prop Hunt Stats page");
}

//SQL_TConnect doesn't support persistent connections, so just use SQL_Connect
static Handle:LocalStats_Connect(String:error[]="")
{
	new Handle:db = INVALID_HANDLE;
	decl String:error[255];
	
	if (SQL_CheckConfig(DATABASE))
	{
		db = SQL_Connect(DATABASE, true, error, sizeof(error));
		if (db != INVALID_HANDLE)
		{
			SQL_FastQuery("SET NAMES 'utf8'");
		}
	}
	
	return db;
}

LocalStats_OnClientDisconnect(client)
{
	// TODO: Do something with disconnecting clients
}

LocalStats_OnClientDisconnect_Post(client)
{
	// TODO: Do something with disconnecting clients
}

LocalStats_DbRound(winner)
{
	// TODO: Do something with round winners
}

LocalStats_AlterScore(client, points, ScReason:reason, time)
{
	// TODO: Do something with round winners
}

LocalStats_OnClientPostAdminCheck(client)
{
	// TODO: Post-logon stuff
}
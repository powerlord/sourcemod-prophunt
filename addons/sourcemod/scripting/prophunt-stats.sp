// PropHunt Redux Stats by Powerlord
//  - reddit.com/r/RUGC_Midwest -

// This plugin just has the commands to create and upgrade the Local Stats database

// This is based heavily on the SourceMod SQLAdmins code because I'm lazy.

#pragma semicolon 1
#include <sourcemod>

#define CURRENT_SCHEMA_VERSION		1409
#define SCHEMA_UPGRADE_1			1409

new current_version[4] = {3, 1, 0, CURRENT_SCHEMA_VERSION};

#define MYSQL "mysql"
#define SQLITE "sqlite"

#define PL_VERSION "3.1.0 alpha 1"

public Plugin:myinfo = 
{
	name = "PropHunt Redux Local Stats Manager",
	author = "Powerlord",
	description = "Create/Update PropHunt Redux's local stats DB",
	version = PL_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=228086"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	RegServerCmd("ph_create_stats_tables", Command_CreateTables);
	RegServerCmd("ph_update_stats_tables", Command_UpdateTables);
	
}

Handle:Connect()
{
	decl String:error[255];
	new Handle:db;
	
	if (SQL_CheckConfig("prophunt_local"))
	{
		db = SQL_Connect("prophunt_local", true, error, sizeof(error));
	} else {
		db = SQL_Connect("default", true, error, sizeof(error));
	}
	
	if (db == INVALID_HANDLE)
	{
		LogError("Could not connect to database: %s", error);
	}
	
	return db;
}

CreateMySQL(client, Handle:db)
{
	new String:queries[7][1024];
	
	Format(queries[0], sizeof(queries[]), "CREATE TABLE ph_servers (id int(10) unsigned NOT NULL auto_increment, ip varchar(65), points int(10), time int(10), PRIMARY KEY(id) )");
	Format(queries[1], sizeof(queries[]), "CREATE TABLE ph_players (steamid varchar(25), name varchar(%d), points int(10), wins int(10), losses int(10), time int(10), PRIMARY KEY(steamid) )", MAX_NAME_LENGTH);
	Format(queries[2], sizeof(queries[]), "CREATE TABLE ph_deaths (id int(10) unsigned NOT NULL auto_increment, victimid varchar(25), killerid varchar(20), killerteam int(1), weapon varchar(64), assisterid varchar(25), ip varchar(65), map varchar(%d), prop varchar(%d), victim_position_x float, victim_position_y float, victim_position_z float, killer_position_x float, killer_position_y float, killer_position_z float, victim_class int(1), killer_class int(1), survival_time int(4), PRIMARY KEY(id) )", PLATFORM_MAX_PATH, PLATFORM_MAX_PATH);
	Format(queries[3], sizeof(queries[]), "CREATE TABLE ph_survivals (id int(10) unsigned NOT NULL auto_increment, steamid varchar(25), prop varchar(%d), ip varchar(65), map varchar(%d), position_x float, position_y float, position_z float, class int(1), team int(1), survival_time int(4), PRIMARY KEY(id) )", PLATFORM_MAX_PATH, PLATFORM_MAX_PATH);
	Format(queries[4], sizeof(queries[]), "CREATE TABLE ph_rounds (id int(10) unsigned NOT NULL auto_increment, team char(3), map varchar(%d), ip varchar(65), PRIMARY KEY(id) )", PLATFORM_MAX_PATH);
	Format(queries[5], sizeof(queries[]), "CREATE TABLE ph_props (id int(10) unsigned NOT NULL auto_increment, name varchar(%d), deaths int(10), survivals int(10))", PLATFORM_MAX_PATH);
	Format(queries[6], sizeof(queries[]), "CREATE TABLE IF NOT EXISTS ph_config (cfg_key varchar(32) NOT NULL, cfg_value varchar(255) NOT NULL, PRIMARY KEY (cfg_key))");
	
	for (new i = 0; i < 7; i++)
	{
		if (!DoQuery(client, db, queries[i]))
		{
			return;
		}
	}

	decl String:query[256];
	Format(query, 
		sizeof(query), 
		"INSERT INTO ph_config (cfg_key, cfg_value) VALUES ('schema_version', '3.1.0.%d') ON DUPLICATE KEY UPDATE cfg_value = '3.1.0.%d'",
		CURRENT_SCHEMA_VERSION,
		CURRENT_SCHEMA_VERSION);

	if (!DoQuery(client, db, query))
	{
		return;
	}

	ReplyToCommand(client, "[PH] Stats tables have been created.");
}

public Action:Command_CreateTables(args)
{
	new client = 0;
	new Handle:db = Connect();
	if (db == INVALID_HANDLE)
	{
		ReplyToCommand(client, "[PH] %t", "Could not connect to database");
		return Plugin_Handled;
	}

	new String:ident[16];
	SQL_ReadDriver(db, ident, sizeof(ident));

	if (strcmp(ident, "mysql") == 0)
	{
		CreateMySQL(client, db);
	} else if (strcmp(ident, "sqlite") == 0) {
		ReplyToCommand(client, "[PH] SQLite is not supported at this time.");
	} else {
		ReplyToCommand(client, "[PH] Unknown driver type '%s', cannot create tables.", ident);
	}

	CloseHandle(db);

	return Plugin_Handled;
}

bool:GetUpdateVersion(client, Handle:db, versions[4])
{
	decl String:query[256];
	new Handle:hQuery;

	Format(query, sizeof(query), "SELECT cfg_value FROM ph_config WHERE cfg_key = 'schema_version'");
	if ((hQuery = SQL_Query(db, query)) == INVALID_HANDLE)
	{
		DoError(client, db, query, "Version lookup query failed");
		return false;
	}
	if (SQL_FetchRow(hQuery))
	{
		decl String:version_string[255];
		SQL_FetchString(hQuery, 0, version_string, sizeof(version_string));

		decl String:version_numbers[4][12];
		if (ExplodeString(version_string, ".", version_numbers, 4, 12) == 4)
		{
			for (new i = 0; i < 4; i++)
			{
				versions[i] = StringToInt(version_numbers[i]);
			}
		}
	}

	CloseHandle(hQuery);

	if (current_version[3] < versions[3])
	{
		ReplyToCommand(client, "[PH] The database is newer than the expected version.");
		return false;
	}

	if (current_version[3] == versions[3])
	{
		ReplyToCommand(client, "[PH] Your tables are already up to date.");
		return false;
	}


	return true;
}

UpdateMySQL(client, Handle:db)
{
	decl String:query[512];
	new Handle:hQuery;
	
	Format(query, sizeof(query), "SHOW TABLES");
	if ((hQuery = SQL_Query(db, query)) == INVALID_HANDLE)
	{
		DoError(client, db, query, "Table lookup query failed");
		return;
	}

	decl String:table[64];
	new bool:found = false;
	while (SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 0, table, sizeof(table));
		if (strcmp(table, "ph_config") == 0)
		{
			found = true;
		}
	}
	CloseHandle(hQuery);

	new versions[4];

	if (found && !GetUpdateVersion(client, db, versions))
	{
		return;
	}

	/*
	 * There are presently no upgrades
	 */
	if (versions[3] < SCHEMA_UPGRADE_1)
	{
		/*
		new String:queries[6][] = 
		{
			"CREATE TABLE IF NOT EXISTS sm_config (cfg_key varchar(32) NOT NULL, cfg_value varchar(255) NOT NULL, PRIMARY KEY (cfg_key))",
			"ALTER TABLE sm_admins ADD immunity INT UNSIGNED NOT NULL",
			"ALTER TABLE sm_groups ADD immunity_level INT UNSIGNED NOT NULL",
			"UPDATE sm_groups SET immunity_level = 2 WHERE immunity = 'default'",
			"UPDATE sm_groups SET immunity_level = 1 WHERE immunity = 'global'",
			"ALTER TABLE sm_groups DROP immunity"
		};

		for (new i = 0; i < 6; i++)
		{
			if (!DoQuery(client, db, queries[i]))
			{
				return;
			}
		}

		decl String:upgr[48];
		Format(upgr, sizeof(upgr), "1.0.0.%d", SCHEMA_UPGRADE_1);

		Format(query, sizeof(query), "INSERT INTO ph_config (cfg_key, cfg_value) VALUES ('schema_version', '%s') ON DUPLICATE KEY UPDATE cfg_value = '%s'", upgr, upgr);
		if (!DoQuery(client, db, query))
		{
			return;
		}

		versions[3] = SCHEMA_UPGRADE_1;
		*/
	}

	//ReplyToCommand(client, "[PH] Your tables are now up to date.");
	ReplyToCommand(client, "[PH] There are no upgrades at this time.");
}

public Action:Command_UpdateTables(args)
{
	new client = 0;
	new Handle:db = Connect();
	if (db == INVALID_HANDLE)
	{
		ReplyToCommand(client, "[PH] %t", "Could not connect to database");
		return Plugin_Handled;
	}

	new String:ident[16];
	SQL_ReadDriver(db, ident, sizeof(ident));

	if (strcmp(ident, "mysql") == 0)
	{
		UpdateMySQL(client, db);
	} else if (strcmp(ident, "sqlite") == 0) {
		ReplyToCommand(client, "[PH] SQLite is not supported at this time.");
	} else {
		ReplyToCommand(client, "[PH] Unknown driver type, cannot upgrade.");
	}

	CloseHandle(db);

	return Plugin_Handled;
}

stock bool:DoQuery(client, Handle:db, const String:query[])
{
	if (!SQL_FastQuery(db, query))
	{
		decl String:error[255];
		SQL_GetError(db, error, sizeof(error));
		LogError("Query failed: %s", error);
		LogError("Query dump: %s", query);
		ReplyToCommand(client, "[PH] %t", "Failed to query database");
		return false;
	}

	return true;
}

stock Action:DoError(client, Handle:db, const String:query[], const String:msg[])
{
		decl String:error[255];
		SQL_GetError(db, error, sizeof(error));
		LogError("%s: %s", msg, error);
		LogError("Query dump: %s", query);
		CloseHandle(db);
		ReplyToCommand(client, "[PH] %t", "Failed to query database");
		return Plugin_Handled;
}

stock Action:DoStmtError(client, Handle:db, const String:query[], const String:error[], const String:msg[])
{
		LogError("%s: %s", msg, error);
		LogError("Query dump: %s", query);
		CloseHandle(db);
		ReplyToCommand(client, "[PH] %t", "Failed to query database");
		return Plugin_Handled;
}


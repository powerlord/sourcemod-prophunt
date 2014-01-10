// PropHunt Redux Local Stats by Powerlord
//     - reddit.com/r/RUGC_Midwest -

// This is based heavily on the SourceMod SQLAdmins code because I'm lazy.

// Don't use this code yet, it's not finished
/*
 * NOTE: Queries used when connecting to the DB are non-threaded because we want them to complete before
 * any threaded queries would run
 */

#define CURRENT_SCHEMA_VERSION		1
#define SCHEMA_UPGRADE_1			1

#define MYSQL "mysql"
#define SQLITE "sqlite"
static Handle:g_LocalDb;

LocalStats_Init()
{
	g_LocalDb = LocalStats_Connect();
	RegServerCmd("ph_create_stats_tables", LocalStats_CreateTables, "Create PropHunt Stats Tables");
	RegServerCmd("ph_update_stats_tables", LocalStats_UpdateTables, "Update PropHunt Stats Tables");
}

public Action:LocalStats_UpdateTables(args)
{
	new client = 0;
	ReplyToCommand(client, "This command doesn't do anything yet.");
}

public Action:LocalStats_CreateTables(args)
{
	new client = 0;
	new Handle:db = LocalStats_Connect();

	if (db == INVALID_HANDLE)
	{
		ReplyToCommand(client, "[PH] %t", "Could not connect to database");
		return Plugin_Handled;
	}

	new String:ident[16];
	SQL_ReadDriver(db, ident, sizeof(ident));
	
	if (strcmp(ident, "mysql") == 0)
	{
		LocalStats_CreateMySQL(client, db);
	} else if (strcmp(ident, "sqlite") == 0) {
		LocalStats_CreateSQLite(client, db);
	} else {
		ReplyToCommand(client, "[PH] Unknown driver type '%s', cannot create PropHunt stats tables.", ident);
	}
	
	CloseHandle(db);
	
	return Plugin_Handled;
}

static LocalStats_CreateMySQL(client, Handle:db)
{
	new String:queries[6][1024];
	
	Format(queries[0], sizeof(queries[]), "CREATE TABLE ph_servers (id int(10) unsigned NOT NULL auto_increment, ip varchar(65), points int(10), time int(10), PRIMARY KEY(id) )");
	Format(queries[1], sizeof(queries[]), "CREATE TABLE ph_players (steamid varchar(25), name varchar(%d), points int(10), wins int(10), losses int(10), time int(10), PRIMARY KEY(steamid) )", MAX_NAME_LENGTH);
	Format(queries[2], sizeof(queries[]), "CREATE TABLE ph_deaths (id int(10) unsigned NOT NULL auto_increment, victimid varchar(25), killerid varchar(20), killerteam int(1), weapon varchar(64), assisterid varchar(25), ip varchar(65), map varchar(%d), prop varchar(%d), victim_position_x float, victim_position_y float, victim_position_z float, killer_position_x float, killer_position_y float, killer_position_z float, victim_class int(1), killer_class int(1), survival_time int(4), PRIMARY KEY(id) )", PLATFORM_MAX_PATH, PLATFORM_MAX_PATH);
	Format(queries[3], sizeof(queries[]), "CREATE TABLE ph_survivals (id int(10) unsigned NOT NULL auto_increment, steamid varchar(25), prop varchar(%d), ip varchar(65), map varchar(%d), position_x float, position_y float, position_z float, class int(1), team int(1), survival_time int(4), PRIMARY KEY(id) )", PLATFORM_MAX_PATH, PLATFORM_MAX_PATH);
	Format(queries[4], sizeof(queries[]), "CREATE TABLE ph_rounds (id int(10) unsigned NOT NULL auto_increment, team char(3), map varchar(%d), ip varchar(65), PRIMARY KEY(id) )", PLATFORM_MAX_PATH);
	Format(queries[5], sizeof(queries[]), "CREATE TABLE ph_props (id int(10) unsigned NOT NULL auto_increment, name varchar(%d), deaths int(10), survivals int(10))", PLATFORM_MAX_PATH;
	
	
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
		"INSERT INTO ph_config (cfg_key, cfg_value) VALUES ('schema_version', '%d') ON DUPLICATE KEY UPDATE cfg_value = '%d'",
		CURRENT_SCHEMA_VERSION,
		CURRENT_SCHEMA_VERSION);

	if (!DoQuery(client, db, query))
	{
		return;
	}

	ReplyToCommand(client, "[PH] Stats tables have been created.");
}

static Handle:LocalStats_Connect()
{
	decl String:error[255];
	new Handle:db;
	
	if (SQL_CheckConfig("prophunt"))
	{
		db = SQL_Connect("prophunt", true, error, sizeof(error));
	} else {
		db = SQL_DefConnect(error, sizeof(error), true);
	}
	
	if (db == INVALID_HANDLE)
	{
		LogError("Could not connect to database: %s", error);
	}
	else
	{
		LocalStats_TableCheck();
	}
	
	return db;
}

static LocalStats_TableCheck(Handle:db)
{
	decl String:query[256];
	new Handle:hQuery;
	Format(query, sizeof(query), "SELECT cfg_value FROM prophunt_config WHERE key = 'schema_version'");
	
	SQL_LockDatabase(db);
	if ((hQuery = SQL_Query(db, query)) == INVALID_HANDLE)
	{
		LogError("PropHunt Stats version could not be read.  rcon ph_create_stats_tables must be run first.");
		SQL_UnlockDatabase(db);
		CloseHandle(db);
		return;
	}
	
	decl String:version_string[255];
	SQL_FetchString(hQuery, 0, version_string, sizeof(version_string));
	
	
	SQL_UnlockDatabase(db);
	
	decl String:driver[20];
	SQL_ReadDriver(db, driver, sizeof(driver));
}

LocalStats_OnClientDisconnect(client)
{
	new Handle:db = LocalStats_Connect();
	if (db == INVALID_HANDLE)
		return;
}

LocalStats_OnClientDisconnect_Post(client)
{
	new Handle:db = LocalStats_Connect();
	if (db == INVALID_HANDLE)
		return;
}

static bool:LocalStats_DoQuery(client, Handle:db, const String:query[])
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
// PropHunt Redux Local Stats by Powerlord
// - reddit.com/r/RUGC_Midwest -

// This is based heavily on the SourceMod SQLAdmins code because I'm lazy.

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
	new String:queries[7][] = 
	{
		"CREATE TABLE sm_admins (id int(10) unsigned NOT NULL auto_increment, authtype enum('steam','name','ip') NOT NULL, identity varchar(65) NOT NULL, password varchar(65), flags varchar(30) NOT NULL, name varchar(65) NOT NULL, immunity int(10) unsigned NOT NULL, PRIMARY KEY (id))",
		"CREATE TABLE sm_groups (id int(10) unsigned NOT NULL auto_increment, flags varchar(30) NOT NULL, name varchar(120) NOT NULL, immunity_level int(1) unsigned NOT NULL, PRIMARY KEY (id))",
		"CREATE TABLE sm_group_immunity (group_id int(10) unsigned NOT NULL, other_id int(10) unsigned NOT NULL,  PRIMARY KEY (group_id, other_id))",
		"CREATE TABLE sm_group_overrides (group_id int(10) unsigned NOT NULL, type enum('command','group') NOT NULL, name varchar(32) NOT NULL, access enum('allow','deny') NOT NULL, PRIMARY KEY (group_id, type, name))",
		"CREATE TABLE sm_overrides (type enum('command','group') NOT NULL, name varchar(32) NOT NULL, flags varchar(30) NOT NULL, PRIMARY KEY (type,name))",
		"CREATE TABLE sm_admins_groups (admin_id int(10) unsigned NOT NULL, group_id int(10) unsigned NOT NULL, inherit_order int(10) NOT NULL, PRIMARY KEY (admin_id, group_id))",
		"CREATE TABLE IF NOT EXISTS prophunt_config (cfg_key varchar(32) NOT NULL, cfg_value varchar(255) NOT NULL, PRIMARY KEY (cfg_key))"
	};

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
		"INSERT INTO prophunt_config (cfg_key, cfg_value) VALUES ('schema_version', '%d') ON DUPLICATE KEY UPDATE cfg_value = '%d'",
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
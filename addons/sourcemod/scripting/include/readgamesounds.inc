#include <sourcemod>
#include <sdktools>

/**
 * Retrieves the parameters for a game sound.
 *
 * Game sounds are found in a game's scripts/game_sound.txt or other files
 * referenced from it
 *
 * Note that if a game sound has a rndwave section, one of them will be returned
 * at random.
 *
 * @param gameSound            Name of game sound.
 * @param channel              Channel to emit with.
 * @param level                        Sound level.
 * @param volume               Sound volume.
 * @param pitch                        Sound pitch.
 * @param sample               Sound file name relative to the "sounds" folder.
 * @param maxlength            Maximum length of sample string buffer.
 * @param entity               Entity the sound is being emitted from.
 * @return                             True if the sound was successfully retrieved, false if it failed
 */
native bool:GetGameSoundParams(const String:gameSound[], &channel, &soundLevel, &Float:volume, &pitch, String:sample[], maxlength, entity=SOUND_FROM_PLAYER);

/**
 * Emits a game sound to a list of clients.
 *
 * Game sounds are found in a game's scripts/game_sound.txt or other files
 * referenced from it
 *
 * Note that if a game sound has a rndwave section, one of them will be returned
 * at random.
 *
 * @param clients              Array of client indexes.
 * @param numClients   Number of clients in the array.
 * @param gameSound            Name of game sound.
 * @param entity               Entity to emit from.
 * @param flags                        Sound flags.
 * @param speakerentity        Unknown.
 * @param origin               Sound origin.
 * @param dir                  Sound direction.
 * @param updatePos            Unknown (updates positions?)
 * @param soundtime            Alternate time to play sound for.
 * @return                             True if the sound was played successfully, false if it failed
 * @error                              Invalid client index.
 */
stock bool:EmitGameSound(const clients[],
				numClients,
				const String:gameSound[],
				entity = SOUND_FROM_PLAYER,
				flags = SND_NOFLAGS,
				speakerentity = -1,
				const Float:origin[3] = NULL_VECTOR,
				const Float:dir[3] = NULL_VECTOR,
				bool:updatePos = true,
				Float:soundtime = 0.0)
{
	new channel;
	new level;
	new Float:volume;
	new pitch;
	new String:sample[PLATFORM_MAX_PATH];
	
	if (GetFeatureStatus(FeatureType_Native, "PrecacheScriptSound") == FeatureStatus_Available)
	{
		PrecacheScriptSound(gameSound);
	}
	if (GetFeatureStatus(FeatureType_Native, "GetGameSoundParams") == FeatureStatus_Available && GetGameSoundParams(gameSound, channel, level, volume, pitch, sample, sizeof(sample), entity))
	{
		if (GetFeatureStatus(FeatureType_Native, "PrecacheScriptSound") != FeatureStatus_Available)
		{
			PrecacheSound(sample);
		}
		EmitSound(clients, numClients, sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
		return true;
	}
	else
	{
		return false;
	}
}

/**
 * Emits an ambient game sound.
 *
 * Game sounds are found in a game's scripts/game_sound.txt or other files
 * referenced from it
 *
 * Note that if a game sound has a rndwave section, one of them will be returned
 * at random.
 *
 * @param gameSound            Name of game sound.
 * @param pos                  Origin of sound.
 * @param entity               Entity index to associate sound with.
 * @param flags                        Sound flags.
 * @param delay                        Play delay.
 * @noreturn
 */
stock bool:EmitAmbientGameSound(const String:gameSound[],
                        const Float:pos[3],
                        entity = SOUND_FROM_WORLD,
                        flags = SND_NOFLAGS,
                        Float:delay = 0.0)
{
	new channel; // This is never actually used for Ambients, but it's a mandatory field to GetGameSoundParams
	new level;
	new Float:volume;
	new pitch;
	new String:sample[PLATFORM_MAX_PATH];
	
	if (GetFeatureStatus(FeatureType_Native, "PrecacheScriptSound") == FeatureStatus_Available)
	{
		PrecacheScriptSound(gameSound);
	}

	if (GetFeatureStatus(FeatureType_Native, "GetGameSoundParams") == FeatureStatus_Available && GetGameSoundParams(gameSound, channel, level, volume, pitch, sample, sizeof(sample), entity))
	{
		if (GetFeatureStatus(FeatureType_Native, "PrecacheScriptSound") != FeatureStatus_Available)
		{
			PrecacheSound(sample);
		}
		EmitAmbientSound(sample, pos, entity, level, flags, volume, pitch, delay);
		return true;
	}
	else
	{
		return false;
	}
}

/**
 * Wrapper to emit a game sound to one client.
 *
 * Game sounds are found in a game's scripts/game_sound.txt or other files
 * referenced from it
 *
 * Note that if a game sound has a rndwave section, one of them will be returned
 * at random.
 *
 * @param client               Client index.
 * @param gameSound            Name of game sound.
 * @param entity               Entity to emit from.
 * @param flags                        Sound flags.
 * @param speakerentity        Unknown.
 * @param origin               Sound origin.
 * @param dir                  Sound direction.
 * @param updatePos            Unknown (updates positions?)
 * @param soundtime            Alternate time to play sound for.
 * @noreturn
 * @error                              Invalid client index.
 */
stock bool:EmitGameSoundToClient(client,
				const String:gameSound[],
				entity = SOUND_FROM_PLAYER,
				flags = SND_NOFLAGS,
				speakerentity = -1,
				const Float:origin[3] = NULL_VECTOR,
				const Float:dir[3] = NULL_VECTOR,
				bool:updatePos = true,
				Float:soundtime = 0.0)
{
	new clients[1];
	clients[0] = client;
	/* Save some work for SDKTools and remove SOUND_FROM_PLAYER references */
	entity = (entity == SOUND_FROM_PLAYER) ? client : entity;
	return EmitGameSound(clients, 1, gameSound, entity, flags,
		speakerentity, origin, dir, updatePos, soundtime);
}

/**
 * Wrapper to emit game sound to all clients.
 *
 * Game sounds are found in a game's scripts/game_sound.txt or other files
 * referenced from it
 *
 * Note that if a game sound has a rndwave section, one of them will be returned
 * at random.
 *
 * @param gameSound            Name of game sound.
 * @param entity               Entity to emit from.
 * @param flags                        Sound flags.
 * @param speakerentity        Unknown.
 * @param origin               Sound origin.
 * @param dir                  Sound direction.
 * @param updatePos            Unknown (updates positions?)
 * @param soundtime            Alternate time to play sound for.
 * @noreturn
 * @error                              Invalid client index.
 */
stock bool:EmitGameSoundToAll(const String:gameSound[],
				entity = SOUND_FROM_PLAYER,
				flags = SND_NOFLAGS,
				speakerentity = -1,
				const Float:origin[3] = NULL_VECTOR,
				const Float:dir[3] = NULL_VECTOR,
				bool:updatePos = true,
				Float:soundtime = 0.0)
{
	new clients[MaxClients];
	new total = 0;
	
	for (new i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			clients[total++] = i;
		}
	}
		
	if (!total)
	{
		return false;
	}
		
	return EmitGameSound(clients, total, gameSound, entity, flags,
		speakerentity, origin, dir, updatePos, soundtime);
}

/**
 * Precache a game sound. Use this if you're not sure if a game sound is precached or not.
 *
 * This should be called before any calls to EmitGameSound* or EmitAmbientGameSound
 * 
 * Note: It precaches all files for a game sound.
 * 
 * @param soundname	Game sound to precache
 * 
 * @return 			True if precache was successful, false if not 
 */
native bool:PrecacheScriptSound(const String:soundname[]);

public Extension:__ext_readgamesounds =
{
	name = "readgamesounds",
	file = "readgamesounds.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
}

#if !defined REQUIRE_EXTENSIONS
public __ext_readgamesounds_SetNTVOptional()
{
	MarkNativeAsOptional("GetGameSoundParams");
	MarkNativeAsOptional("PrecacheScriptSound");
}
#endif
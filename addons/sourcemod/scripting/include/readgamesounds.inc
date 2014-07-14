#include <sourcemod>
#include <sdktools>

native bool:GetGameSoundParams(const String:gameSound[], &channel, &soundLevel, &Float:volume, &pitch, String:sample[], maxlength, entity=SOUND_FROM_PLAYER);

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
	
	if (GetFeatureStatus(FeatureType_Native, "GetGameSoundParams") == FeatureStatus_Available && GetGameSoundParams(gameSound, channel, level, volume, pitch, sample, sizeof(sample), entity))
	{
		PrecacheSound(sample);
		EmitSound(clients, numClients, sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
		return true;
	}
	else
	{
		return false;
	}
}

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
	
	if (GetFeatureStatus(FeatureType_Native, "GetGameSoundParams") == FeatureStatus_Available && GetGameSoundParams(gameSound, channel, level, volume, pitch, sample, sizeof(sample), entity))
	{
		PrecacheSound(sample);
		EmitAmbientSound(sample, pos, entity, level, flags, volume, pitch, delay);
		return true;
	}
	else
	{
		return false;
	}
}

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

public __ext_readgamesounds_SetNTVOptional()
{
	MarkNativeAsOptional("GetGameSoundParams");
}
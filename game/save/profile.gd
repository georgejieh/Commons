class_name Profile
extends RefCounted
## The profile save, which outlives every run (ADR 0025). It is a separate file from the
## run save, with its own schema version, and deleting the run save never touches it.
## Its fields are ProfileData's; ProfileCommits decides what a run writes to it.

## The profile save's current schema version, separate from the run save's.
const SCHEMA_VERSION: int = 4
## The first profile schema that carries a seal (ADR 0022).
const SEALED_FROM: int = 4
## The save key of the village's memory of the player.
const MEMORY_KEY: String = "memory"
## The save key of how far each family has drifted.
const DRIFT_KEY: String = "drift"
## The save key of the family's file.
const FILE_KEY: String = "file"


## The profile's save service at path, with its migrations, validator and seal.
static func service(path: String = SaveService.PROFILE_PATH) -> SaveService:
	var migrations: Dictionary[int, Callable] = {
		1: migrate_from_1, 2: migrate_from_2, 3: migrate_from_3
	}
	return SaveService.new(path, migrations, SCHEMA_VERSION, ProfileData.is_valid, SEALED_FROM)


## Schema 1 to 2: the memory stays, and every field ADR 0025 adds starts empty.
static func migrate_from_1(data: Dictionary) -> Dictionary:
	var fresh: Dictionary = ProfileData.new().to_dict()
	if data.has(MEMORY_KEY):
		fresh[MEMORY_KEY] = data[MEMORY_KEY]
	return fresh


## Schema 2 to 3: no family has drifted yet (ADR 0028).
static func migrate_from_2(data: Dictionary) -> Dictionary:
	if not data.has(DRIFT_KEY):
		data[DRIFT_KEY] = {}
	return data


## Schema 3 to 4: the family's file is empty (ADR 0022).
static func migrate_from_3(data: Dictionary) -> Dictionary:
	if not data.has(FILE_KEY):
		data[FILE_KEY] = []
	return data


## The saved profile, or an empty one for a new or damaged profile.
static func read(profile: SaveService) -> ProfileData:
	var loaded: SaveLoad = profile.load_save()
	var usable: bool = (
		loaded.status == SaveLoad.Status.OK or loaded.status == SaveLoad.Status.RESTORED_FROM_BACKUP
	)
	if not usable:
		return ProfileData.new()
	return ProfileData.from_dict(loaded.data)


## Saves the data as the profile, and returns the service's error.
static func write(profile: SaveService, data: ProfileData) -> Error:
	return profile.save(data.to_dict())

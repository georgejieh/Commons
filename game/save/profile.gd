class_name Profile
extends RefCounted
## The profile save, which outlives every run (P4.6, ADR 0025). It is a separate file from
## the run save, with its own schema version, and deleting the run save never touches
## it. Its fields are ProfileData's; ProfileCommits decides what a run writes to it.

const SCHEMA_VERSION: int = 3
const MEMORY_KEY: String = "memory"
const DRIFT_KEY: String = "drift"


static func service(path: String = SaveService.PROFILE_PATH) -> SaveService:
	var migrations: Dictionary[int, Callable] = {1: migrate_from_1, 2: migrate_from_2}
	return SaveService.new(path, migrations, SCHEMA_VERSION, is_valid)


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


## True when the data is a whole profile, every field of its kind.
static func is_valid(data: Dictionary) -> bool:
	return ProfileData.is_valid(data)


## The saved profile, or an empty one for a new or damaged profile.
static func read(profile: SaveService) -> ProfileData:
	var loaded: SaveLoad = profile.load_save()
	var usable: bool = (
		loaded.status == SaveLoad.Status.OK or loaded.status == SaveLoad.Status.RESTORED_FROM_BACKUP
	)
	if not usable:
		return ProfileData.new()
	return ProfileData.from_dict(loaded.data)


static func write(profile: SaveService, data: ProfileData) -> Error:
	return profile.save(data.to_dict())


## What the saved village remembers, or nothing for a new or damaged profile.
static func memory(profile: SaveService) -> VillageMemory:
	return read(profile).memory


## Writes the memory, keeping whatever else the profile holds.
static func save_memory(profile: SaveService, memory: VillageMemory) -> Error:
	var data: ProfileData = read(profile)
	data.memory = memory
	return write(profile, data)

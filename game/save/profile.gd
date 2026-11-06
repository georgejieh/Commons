class_name Profile
extends RefCounted
## The profile save, which outlives every run (P4.6). It is a separate file from the run
## save, with its own schema version. For now it holds only the village's memory of the
## player; P4.14 adds unlocks, history, lineage, stakes and corruption.

const SCHEMA_VERSION: int = 1
const MEMORY_KEY: String = "memory"


static func service(path: String = SaveService.PROFILE_PATH) -> SaveService:
	return SaveService.new(path, {}, SCHEMA_VERSION, is_valid)


## True when the profile's memory is a map of families to four counts each.
static func is_valid(data: Dictionary) -> bool:
	if not data.get(MEMORY_KEY, {}) is Dictionary:
		return false
	var memory: Dictionary = data.get(MEMORY_KEY, {})
	for row: Variant in memory.values():
		if not row is Array:
			return false
		var counts: Array = row
		if counts.size() != SetSummary.KIND_COUNT:
			return false
	return true


## What the saved village remembers, or nothing for a new or damaged profile.
static func memory(profile: SaveService) -> VillageMemory:
	var loaded: SaveLoad = profile.load_save()
	var usable: bool = (
		loaded.status == SaveLoad.Status.OK or loaded.status == SaveLoad.Status.RESTORED_FROM_BACKUP
	)
	if not usable:
		return VillageMemory.new()
	return VillageMemory.from_dict(loaded.data.get(MEMORY_KEY, {}))


## Writes the memory, keeping whatever else the profile holds.
static func save_memory(profile: SaveService, memory: VillageMemory) -> Error:
	var data: Dictionary = {}
	var loaded: SaveLoad = profile.load_save()
	if loaded.status == SaveLoad.Status.OK or loaded.status == SaveLoad.Status.RESTORED_FROM_BACKUP:
		data = loaded.data
	data[MEMORY_KEY] = memory.to_dict()
	return profile.save(data)

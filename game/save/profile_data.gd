class_name ProfileData
extends RefCounted
## What the profile save holds (ADR 0025), as typed values. Profile reads and writes it;
## ProfileCommits decides what a run may change in it. A new profile is every field at
## its empty value.

const HISTORY_CAP: int = 50
const CORRUPTION_MAX: float = 100.0
## A key written since schema 2 began: a profile from before it reads it from its history.
const LANDLORD_ENDINGS_KEY: String = "landlord_endings"
## Keys every schema 4 profile holds.
const KEYS: Array[String] = [
	"memory",
	"generation",
	"finished_runs",
	"wins",
	"history",
	"lineage",
	"stake",
	"corruption",
	"seen",
	"surname",
	"committed",
	"drift",
	"file",
]

## The village's memory of the player.
var memory: VillageMemory = VillageMemory.new()
## Runs the family has started; a new run is the next generation.
var generation: int = 0
## Full runs that reached an ending or a death, and those that survived the last Year.
var finished_runs: int = 0
var wins: int = 0
## Full runs that ended in a landlord's ending, not a death. Kept as a count, so an unlock
## that depends on one outlives the history's cap.
var landlord_endings: int = 0
## One entry per finished full run, newest last, at most HISTORY_CAP.
var history: Array[HistoryEntry] = []
## What the last finished run left the next one: a kind and its values, empty for none.
var lineage_kind: String = ""
var lineage_values: Dictionary = {}
## The highest stake unlocked.
var stake: int = 0
## From 0 to CORRUPTION_MAX, kept clamped (ADR 0018).
var corruption: float = 0.0:
	set(value):
		corruption = clampf(value, 0.0, CORRUPTION_MAX)
## One-time tooltips already shown (ADR 0026), and the family's surname (ADR 0028).
var seen: Array[String] = []
var surname: String = ""
## The run whose Quotas the profile last took, and the last Quota it took from it, so a
## Quota is never taken twice (ADR 0025).
var committed_run: String = ""
var committed_quota: int = -1
## How far each family has drifted over the generations (ADR 0028), written with the
## generation each full run starts.
var drift: VillageDrift = VillageDrift.new()
## The family's file (ADR 0022): every offence the game acted on, oldest first. Nothing
## clears it but deleting the profile.
var file: Array[FileEntry] = []


static func from_dict(data: Dictionary) -> ProfileData:
	var profile: ProfileData = ProfileData.new()
	profile.memory = VillageMemory.from_dict(data["memory"])
	profile.generation = int(data["generation"])
	profile.finished_runs = int(data["finished_runs"])
	profile.wins = int(data["wins"])
	for entry: Dictionary in data["history"]:
		profile.history.append(HistoryEntry.from_dict(entry))
	profile.landlord_endings = int(
		data.get(LANDLORD_ENDINGS_KEY, profile.history_landlord_endings())
	)
	var lineage: Dictionary = data["lineage"]
	var values: Dictionary = lineage["values"]
	profile.lineage_kind = str(lineage["kind"])
	profile.lineage_values = values.duplicate(true)
	profile.stake = int(data["stake"])
	profile.corruption = RunState.float_from_text(str(data["corruption"]))
	profile.seen.assign(data["seen"])
	profile.surname = str(data["surname"])
	var committed: Dictionary = data["committed"]
	profile.committed_run = str(committed["run_id"])
	profile.committed_quota = int(committed["quota"])
	profile.drift = VillageDrift.from_dict(data["drift"])
	for entry: Dictionary in data["file"]:
		profile.file.append(FileEntry.from_dict(entry))
	return profile


func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: HistoryEntry in history:
		entries.append(entry.to_dict())
	var filed: Array[Dictionary] = []
	for entry: FileEntry in file:
		filed.append(entry.to_dict())
	return {
		"memory": memory.to_dict(),
		"generation": generation,
		"finished_runs": finished_runs,
		"wins": wins,
		"landlord_endings": landlord_endings,
		"history": entries,
		"lineage": {"kind": lineage_kind, "values": lineage_values.duplicate(true)},
		"stake": stake,
		"corruption": RunState.float_text(corruption),
		"seen": seen.duplicate(),
		"surname": surname,
		"committed": {"run_id": committed_run, "quota": committed_quota},
		"drift": drift.to_dict(),
		"file": filed,
	}


## True when history holds a record of the run.
func has_run(run_id: String) -> bool:
	return history.any(func(entry: HistoryEntry) -> bool: return entry.run_id == run_id)


## True when the file holds an entry under the key.
func has_entry(key: String) -> bool:
	return file.any(func(entry: FileEntry) -> bool: return entry.key == key)


## Adds a finished run's record, dropping the oldest past the cap.
func add_history(entry: HistoryEntry) -> void:
	history.append(entry)
	while history.size() > HISTORY_CAP:
		history.pop_front()


## The landlord endings the history holds, which a profile from before the count began
## starts from.
func history_landlord_endings() -> int:
	var count: int = 0
	for entry: HistoryEntry in history:
		if entry.class_id == HistoryEntry.LANDLORD and not Endings.is_death(entry.outcome):
			count += 1
	return count


## A whole number from 0, as JSON reads one.
static func is_count(value: Variant) -> bool:
	return (value is int or value is float) and value >= 0 and value == floorf(value)


## True when data is a whole schema 4 profile: every field, each of its kind.
static func is_valid(data: Dictionary) -> bool:
	for key: String in KEYS:
		if not data.has(key):
			return false
	if not _memory_valid(data["memory"]):
		return false
	for key: String in ["generation", "finished_runs", "wins", "stake"]:
		if not is_count(data[key]):
			return false
	if data.has(LANDLORD_ENDINGS_KEY) and not is_count(data[LANDLORD_ENDINGS_KEY]):
		return false
	if not _history_valid(data["history"]):
		return false
	if not _lineage_valid(data["lineage"]) or not _committed_valid(data["committed"]):
		return false
	if not _float_text_valid(data["corruption"]) or not data["surname"] is String:
		return false
	if not VillageDrift.is_valid(data["drift"]) or not _file_valid(data["file"]):
		return false
	return _strings_valid(data["seen"])


static func _file_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var entries: Array = value
	for entry: Variant in entries:
		if not FileEntry.is_valid(entry):
			return false
	return true


static func _history_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var entries: Array = value
	if entries.size() > HISTORY_CAP:
		return false
	for entry: Variant in entries:
		if not HistoryEntry.is_valid(entry):
			return false
	return true


## An array of strings.
static func _strings_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var items: Array = value
	for item: Variant in items:
		if not item is String:
			return false
	return true


## A map of families to four counts each, every count a saved float.
static func _memory_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var memory: Dictionary = value
	for row: Variant in memory.values():
		if not row is Array:
			return false
		var counts: Array = row
		if counts.size() != SetSummary.Kind.size():
			return false
		for count: Variant in counts:
			if not _float_text_valid(count):
				return false
	return true


static func _lineage_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var lineage: Dictionary = value
	return lineage.get("kind") is String and lineage.get("values") is Dictionary


static func _committed_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var committed: Dictionary = value
	var quota: Variant = committed.get("quota")
	# From -1, for no Quota taken yet.
	var number: bool = quota is int or quota is float
	return committed.get("run_id") is String and number and is_count(quota + 1)


## A float saved as its 16 hex digits of bits (RunState.float_text).
static func _float_text_valid(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return text.length() == 16 and text.is_valid_hex_number()

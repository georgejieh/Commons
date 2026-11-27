class_name HistoryEntry
extends RefCounted
## One finished full run in the profile's history (ADR 0025): its ID, its generation, how
## it ended, the class it ended in, the Year it ended in, the household and stake it was
## played with, and the surname keys of the families that died in it. Names are keys, so
## a sent-down youth is still named after their run is gone.

## The class of a run that ended as a landlord.
const LANDLORD: String = "landlord"
## The class of a run that ended as a peasant.
const PEASANT: String = "peasant"

## The ID of the finished run.
var run_id: String = ""
## The generation the finished run was.
var generation: int = 0
## An ending's ID, or a death's.
var outcome: String = ""
## LANDLORD or PEASANT.
var class_id: String = PEASANT
## The Year the run ended in, from 1.
var year: int = 1
## The ID of the household the run was played with, or empty.
var household: String = ""
## The stake the run was played at, from 0.
var stake: int = 0
## The surname keys of the families that died in the run.
var dead: Array[String] = []


## The entry a saved dictionary holds.
static func from_dict(data: Dictionary) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new()
	entry.run_id = str(data["run_id"])
	entry.generation = int(data["generation"])
	entry.outcome = str(data["outcome"])
	entry.class_id = str(data["class"])
	entry.year = int(data["year"])
	entry.household = str(data["household"])
	entry.stake = int(data["stake"])
	entry.dead.assign(data["dead"])
	return entry


## The entry as it is saved in the profile.
func to_dict() -> Dictionary:
	return {
		"run_id": run_id,
		"generation": generation,
		"outcome": outcome,
		"class": class_id,
		"year": year,
		"household": household,
		"stake": stake,
		"dead": dead.duplicate(),
	}


## True when value holds every field with the right kind of value.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	for key: String in ["run_id", "outcome", "household"]:
		if not data.get(key) is String:
			return false
	if not [LANDLORD, PEASANT].has(data.get("class")):
		return false
	for key: String in ["generation", "year", "stake"]:
		if not ProfileData.is_count(data.get(key)):
			return false
	if not data.get("dead") is Array:
		return false
	var names: Array = data["dead"]
	for name_key: Variant in names:
		if not name_key is String:
			return false
	return true

class_name RunIdentity
extends RefCounted
## Which run this is (ADR 0025): its ID, made from the seed and the start time, its kind,
## the household and stake it began with, the count of finished runs it started from and
## its generation. The profile reads the ID to take a run's record only once; Continue
## reads the kind to rebuild the run that was saved. A tutorial run (ADR 0026) is never
## saved, so Continue never meets one.

enum Kind { DEMO, FULL, TUTORIAL }

var id: String = ""
var kind: Kind = Kind.DEMO
## The household picked at run setup, or empty for none.
var household: String = ""
var stake: int = 0
## Finished runs the profile held when this run started; unlocks read it.
var finished_runs: int = 0
## Which generation of the family plays this run, from 1; 0 for a run outside the profile.
var generation: int = 0


static func make_id(seed_value: int, start_time: int) -> String:
	return "%d-%d" % [seed_value, start_time]


static func from_dict(data: Dictionary) -> RunIdentity:
	var identity: RunIdentity = RunIdentity.new()
	identity.id = str(data["id"])
	identity.kind = int(data["kind"]) as Kind
	identity.household = str(data["household"])
	identity.stake = int(data["stake"])
	identity.finished_runs = int(data["finished_runs"])
	identity.generation = int(data["generation"])
	return identity


func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"household": household,
		"stake": stake,
		"finished_runs": finished_runs,
		"generation": generation,
	}


func is_full() -> bool:
	return kind == Kind.FULL


func is_tutorial() -> bool:
	return kind == Kind.TUTORIAL


## True when data holds every field with the right kind of value.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if not data.get("id") is String or not data.get("household") is String:
		return false
	for key: String in ["kind", "stake", "finished_runs", "generation"]:
		var number: Variant = data.get(key)
		if not (number is int or number is float) or number < 0 or number != floorf(number):
			return false
	return int(data["kind"]) < Kind.size()

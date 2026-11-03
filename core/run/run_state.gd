class_name RunState
extends RefCounted
## Everything a run needs to resume, as one serializable object. Numbers that can pass
## 2^53 are saved as text, because JSON numbers are doubles.

enum SetType { SMALL, LARGE, BOSS }

const NO_DEBUFF: String = ""

var run_seed: int
var streams: RandomStreams
## Years count from 1, Sets and rounds from 0.
var year: int = 1
var set_index: int = 0
var set_type: SetType = SetType.SMALL
var round_index: int = 0
## One debuff ID per round of the current Set; round 0 is always NO_DEBUFF.
var debuff_ladder: Array[String] = []
var famine: int = 0
var denunciation: int = 0
var roster: Array[RosterEntry] = []
var inventory: RunInventory = RunInventory.new()
var coupons: int = 0
var commons_pool: int = 0
var landlord_seat: int = Seats.NONE
var summaries: Array[SetSummary] = []


func _init(seed_value: int) -> void:
	run_seed = seed_value
	streams = RandomStreams.new(seed_value)


static func from_dict(data: Dictionary) -> RunState:
	var state: RunState = RunState.new(str(data["seed"]).to_int())
	state.streams = RandomStreams.from_dict(data["streams"])
	state.year = int(data["year"])
	state.set_index = int(data["set_index"])
	state.set_type = int(data["set_type"]) as SetType
	state.round_index = int(data["round_index"])
	state.debuff_ladder.assign(data["debuff_ladder"])
	state.famine = int(data["famine"])
	state.denunciation = int(data["denunciation"])
	for entry_data: Dictionary in data["roster"]:
		state.roster.append(RosterEntry.from_dict(entry_data))
	state.inventory = RunInventory.from_dict(data["inventory"])
	state.coupons = int(data["coupons"])
	state.commons_pool = str(data["commons_pool"]).to_int()
	state.landlord_seat = int(data["landlord_seat"])
	for summary_data: Dictionary in data["summaries"]:
		state.summaries.append(SetSummary.from_dict(summary_data))
	return state


func to_dict() -> Dictionary:
	var roster_data: Array[Dictionary] = []
	for entry: RosterEntry in roster:
		roster_data.append(entry.to_dict())
	var summary_data: Array[Dictionary] = []
	for summary: SetSummary in summaries:
		summary_data.append(summary.to_dict())
	return {
		"seed": str(run_seed),
		"streams": streams.to_dict(),
		"year": year,
		"set_index": set_index,
		"set_type": set_type,
		"round_index": round_index,
		"debuff_ladder": debuff_ladder.duplicate(),
		"famine": famine,
		"denunciation": denunciation,
		"roster": roster_data,
		"inventory": inventory.to_dict(),
		"coupons": coupons,
		"commons_pool": str(commons_pool),
		"landlord_seat": landlord_seat,
		"summaries": summary_data,
	}

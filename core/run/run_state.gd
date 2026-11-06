class_name RunState
extends RefCounted
## Everything a run needs to resume, as one serializable object. Numbers that can pass
## 2^53 are saved as text, because JSON numbers are doubles, and floats as their exact
## bits, because the JSON writer does not round-trip every double.

enum SetType { SMALL, LARGE, BOSS }

const NO_DEBUFF: String = ""
const NO_BOSS: String = ""
## Family IDs by seat until P4.5 seats the roster.
const DEFAULT_TABLE: Array[String] = ["player", "seat_1", "seat_2"]

var run_seed: int
var phase: RunFlow.State = RunFlow.State.RUN_START
var streams: RandomStreams
## Years count from 1, Sets and rounds from 0.
var year: int = 1
var set_index: int = 0
var set_type: SetType = SetType.SMALL
var round_index: int = 0
## The player's banked score toward the current Set's target.
var set_progress: float = 0.0
## One debuff ID per round of the current Set; round 0 is always NO_DEBUFF.
var debuff_ladder: Array[String] = []
var famine: int = 0
var denunciation: int = 0
## Setback state (P4.1). A meter's setback is armed until it fires, and re-arms once the
## meter falls back below its margin.
var famine_armed: bool = true
var denunciation_armed: bool = true
## Rationing holds while true.
var rationed: bool = false
## Reeducation replaces the next shop visit while true.
var reeducation_due: bool = false
## The village's Resentment of the player (P4.2).
var resentment: int = 0
## Each villager family's own Denunciation, from lies caught at audit (P4.3).
var villager_denunciation: Dictionary[String, int] = {}
## Commons shares paid to the player, and to every peasant, this run (P4.4).
var commons_received: int = 0
var commons_paid: int = 0
## What each family remembers of the player, carried in from the profile (P4.6).
var memory: VillageMemory = VillageMemory.new()
## Families that held the landlord seat for a whole Set this run, and those that have
## already run a boss Set (P4.7).
var risen: Array[String] = []
var risen_used: Array[String] = []
## Officials that have run a boss Set since the pool last cycled.
var officials_used: Array[String] = []
## The current Set's boss, or NO_BOSS, and the risen family seated as it.
var boss_id: String = NO_BOSS
var boss_family: String = ""
## How the player played their most recent Sets, oldest first.
var styles: Array[PlayerStyle] = []
var roster: Array[RosterEntry] = []
## The family in each seat this Set.
var table: Array[String] = DEFAULT_TABLE.duplicate()
var inventory: RunInventory = RunInventory.new()
var coupons: int = 0
var commons_pool: int = 0
var landlord_seat: int = Seats.NONE
var summaries: Array[SetSummary] = []
## What the player has seen each villager do this run, for the dossier.
var observations: Observations = Observations.new()


func _init(seed_value: int) -> void:
	run_seed = seed_value
	streams = RandomStreams.new(seed_value)


static func from_dict(data: Dictionary) -> RunState:
	var state: RunState = RunState.new(str(data["seed"]).to_int())
	state.streams = RandomStreams.from_dict(data["streams"])
	state.phase = int(data["phase"]) as RunFlow.State
	state.year = int(data["year"])
	state.set_index = int(data["set_index"])
	state.set_type = int(data["set_type"]) as SetType
	state.round_index = int(data["round_index"])
	state.set_progress = float_from_text(str(data["set_progress"]))
	state.debuff_ladder.assign(data["debuff_ladder"])
	state.famine = int(data["famine"])
	state.denunciation = int(data["denunciation"])
	state.famine_armed = bool(data["famine_armed"])
	state.denunciation_armed = bool(data["denunciation_armed"])
	state.rationed = bool(data["rationed"])
	state.reeducation_due = bool(data["reeducation_due"])
	state.resentment = int(data["resentment"])
	state.commons_received = str(data["commons_received"]).to_int()
	state.commons_paid = str(data["commons_paid"]).to_int()
	state.memory = VillageMemory.from_dict(data["memory"])
	state.risen.assign(data["risen"])
	state.risen_used.assign(data["risen_used"])
	state.officials_used.assign(data["officials_used"])
	state.boss_id = str(data["boss_id"])
	state.boss_family = str(data["boss_family"])
	for style_data: Dictionary in data["styles"]:
		state.styles.append(PlayerStyle.from_dict(style_data))
	for family_id: String in data["villager_denunciation"]:
		state.villager_denunciation[family_id] = int(data["villager_denunciation"][family_id])
	state.table.assign(data["table"])
	for entry_data: Dictionary in data["roster"]:
		state.roster.append(RosterEntry.from_dict(entry_data))
	state.inventory = RunInventory.from_dict(data["inventory"])
	state.coupons = int(data["coupons"])
	state.commons_pool = str(data["commons_pool"]).to_int()
	state.landlord_seat = int(data["landlord_seat"])
	for summary_data: Dictionary in data["summaries"]:
		state.summaries.append(SetSummary.from_dict(summary_data))
	state.observations = Observations.from_dict(data["observations"])
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
		"phase": phase,
		"year": year,
		"set_index": set_index,
		"set_type": set_type,
		"round_index": round_index,
		"set_progress": float_text(set_progress),
		"debuff_ladder": debuff_ladder.duplicate(),
		"famine": famine,
		"denunciation": denunciation,
		"famine_armed": famine_armed,
		"denunciation_armed": denunciation_armed,
		"rationed": rationed,
		"reeducation_due": reeducation_due,
		"resentment": resentment,
		"commons_received": str(commons_received),
		"commons_paid": str(commons_paid),
		"memory": memory.to_dict(),
		"risen": risen.duplicate(),
		"risen_used": risen_used.duplicate(),
		"officials_used": officials_used.duplicate(),
		"boss_id": boss_id,
		"boss_family": boss_family,
		"styles": styles.map(func(style: PlayerStyle) -> Dictionary: return style.to_dict()),
		"villager_denunciation": villager_denunciation.duplicate(),
		"roster": roster_data,
		"table": table.duplicate(),
		"inventory": inventory.to_dict(),
		"coupons": coupons,
		"commons_pool": str(commons_pool),
		"landlord_seat": landlord_seat,
		"summaries": summary_data,
		"observations": observations.to_dict(),
	}


## Halves keep the text unsigned, as RandomStream does.
static func float_text(value: float) -> String:
	var bits: int = PackedFloat64Array([value]).to_byte_array().decode_s64(0)
	return "%08x%08x" % [(bits >> 32) & 0xFFFFFFFF, bits & 0xFFFFFFFF]


static func float_from_text(text: String) -> float:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, (text.substr(0, 8).hex_to_int() << 32) | text.substr(8).hex_to_int())
	return bytes.decode_double(0)

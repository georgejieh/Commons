class_name RunRecord
extends RefCounted
## What a save holds: the RunState where the loop last stood still, at a Set's start or
## end, and the player's commands since. The loop is deterministic, so replaying the
## commands on that state rebuilds any moment in between exactly, the Set's log too.

## Each command type and the fields its replay reads.
## Array values, because a constant of PackedStringArray values reads garbage in 4.7.2.
const COMMAND_FIELDS: Dictionary[String, Array] = {
	"bid": ["claim"],
	"swap": ["hand", "plot"],
	"play": ["cards"],
	"need": ["need"],
	"shop": [],
	"buy": ["slot"],
	"reroll": [],
	"market_buy": ["slot"],
	"market_reroll": [],
	"upgrade": ["kind"],
	"plot_card": ["slot"],
}

var checkpoint: Dictionary = {}
var commands: Array[Dictionary] = []


## Schema 1 to 2: runs saved before the dossier start with nothing observed.
static func migrate_from_1(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		if not checkpoint.has("observations"):
			checkpoint["observations"] = {}
	return data


## Version 2 saves predate the meter setbacks (P4.1): armed, with none in force, and
## Resentment (P4.2) at zero, villagers' Denunciation (P4.3) empty, and no
## Commons paid yet (P4.4), no memory carried in (P4.6), and no
## bosses or styles yet (P4.7), and the plot counter at its start (P4.8).
static func migrate_from_2(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge(_phase_4_defaults())
	return data


## Version 3 saves predate the state store's limited stock (P4.10): nothing sold yet.
## Schema 3 was written all through Phase 4 while its fields were still being added, so
## a save from the middle of it may lack some: every Phase 4 field missing gets the
## value a run starts with.
static func migrate_from_3(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge(_phase_4_defaults())
	return data


## Every field Phase 4 added to a run, at the value a run starts with.
static func _phase_4_defaults() -> Dictionary:
	return {
		"famine_armed": true,
		"denunciation_armed": true,
		"rationed": false,
		"reeducation_due": false,
		"resentment": 0,
		"villager_denunciation": {},
		"commons_received": "0",
		"commons_paid": "0",
		"memory": {},
		"risen": [],
		"risen_used": [],
		"officials_used": [],
		"boss_id": "",
		"next_plot_id": CardInstance.FIRST_PLOT_ID,
		"plot_capacity_bonus": 0,
		"swap_bonus": 0,
		"boss_family": "",
		"styles": [],
		"store_sold": {},
	}


## True when data has a checkpoint with every RunState field and well-formed commands,
## so a save that parses but lost its shape falls back to the backup.
static func is_valid(data: Dictionary) -> bool:
	if not data.get("checkpoint") is Dictionary or not data.get("commands") is Array:
		return false
	var checkpoint: Dictionary = data["checkpoint"]
	for key: String in RunState.new(0).to_dict():
		if not checkpoint.has(key):
			return false
	if not _observations_valid(checkpoint["observations"]):
		return false
	if not _shapes_valid(checkpoint):
		return false
	var phase: Variant = checkpoint["phase"]
	if not (phase is int or phase is float) or phase < 0 or phase >= RunFlow.State.size():
		return false
	for entry: Variant in data["commands"]:
		if not entry is Dictionary:
			return false
		var command: Dictionary = entry
		var type: String = str(command.get("type"))
		if not COMMAND_FIELDS.has(type):
			return false
		for field: String in COMMAND_FIELDS[type]:
			if not command.has(field):
				return false
	return true


## Returns null when a saved command no longer applies, so the caller can fall back.
static func resume(
	data: Dictionary,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	params: RunParams = RunLoop.DEFAULT_PARAMS,
	pool: Array[ModifierDef] = RunLoop.DEFAULT_POOL.debuffs,
	meters: MeterTable = RunLoop.DEFAULT_METERS
) -> RunLoop:
	var loop: RunLoop = RunLoop.new(
		RunState.from_dict(data["checkpoint"]), configs, sets, params, pool, meters
	)
	# The resumed loop's own record starts from the same checkpoint, so its next save
	# keeps it even when no new Set starts first, as in the store.
	loop.record.mark(loop.state)
	loop.resume_at_checkpoint()
	for command: Dictionary in data["commands"]:
		if _replay(loop, command) != RunLoop.Reason.OK:
			return null
	return loop


static func _replay(loop: RunLoop, command: Dictionary) -> RunLoop.Reason:
	match str(command["type"]):
		"bid":
			return loop.player_bid(bool(command["claim"]))
		"swap":
			return loop.player_swap(_ids(command["hand"]), _ids(command["plot"]))
		"play":
			return loop.player_play(_ids(command["cards"]))
		"need":
			return loop.player_need(int(command["need"]))
		"shop":
			return loop.open_shop()
		"buy":
			return loop.player_buy(int(command["slot"]))
		"reroll":
			return loop.player_reroll()
		"market_buy":
			return loop.player_market_buy(int(command["slot"]))
		"market_reroll":
			return loop.player_market_reroll()
		"upgrade":
			return loop.player_upgrade(str(command["kind"]))
		"plot_card":
			return loop.player_plot_card(int(command["slot"]))
	return RunLoop.Reason.ILLEGAL


## Every saved field holds the kind of value a fresh run's does: a dictionary where one
## belongs, an array where one belongs. A save that fails here is damaged, and the save
## service falls back to its backup instead of loading it.
static func _shapes_valid(checkpoint: Dictionary) -> bool:
	var fresh: Dictionary = RunState.new(0).to_dict()
	for key: String in fresh:
		if fresh[key] is Dictionary and not checkpoint[key] is Dictionary:
			return false
		if fresh[key] is Array and not checkpoint[key] is Array:
			return false
	return true


## JSON reads every number as a float.
static func _ids(values: Array) -> Array[int]:
	var ids: Array[int] = []
	for value: Variant in values:
		ids.append(int(value))
	return ids


func mark(state: RunState) -> void:
	checkpoint = state.to_dict()
	commands.clear()


func add(command: Dictionary) -> void:
	commands.append(command)


func to_dict() -> Dictionary:
	return {"checkpoint": checkpoint.duplicate(true), "commands": commands.duplicate(true)}


## Observations are a dictionary of family IDs to arrays of counts.
static func _observations_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var observations: Dictionary = value
	for family: Variant in observations:
		if not family is String or not observations[family] is Array:
			return false
	return true

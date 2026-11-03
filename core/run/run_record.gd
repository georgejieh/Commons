class_name RunRecord
extends RefCounted
## What a save holds: the RunState where the loop last stood still, at a Set's start or
## end, and the player's commands since. The loop is deterministic, so replaying the
## commands on that state rebuilds any moment in between exactly, the Set's log too.

## Each command type and the fields its replay reads.
## Array values, because a constant of PackedStringArray values reads garbage in 4.7.2.
const COMMAND_FIELDS: Dictionary[String, Array] = {
	"bid": ["claim"], "swap": ["hand", "plot"], "play": ["cards"], "need": ["need"]
}

var checkpoint: Dictionary = {}
var commands: Array[Dictionary] = []


## True when data has a checkpoint with every RunState field and well-formed commands,
## so a save that parses but lost its shape falls back to the backup.
static func is_valid(data: Dictionary) -> bool:
	if not data.get("checkpoint") is Dictionary or not data.get("commands") is Array:
		return false
	var checkpoint: Dictionary = data["checkpoint"]
	for key: String in RunState.new(0).to_dict():
		if not checkpoint.has(key):
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
	pool: Array[ModifierDef] = RunLoop.DEFAULT_POOL.debuffs
) -> RunLoop:
	var loop: RunLoop = RunLoop.new(
		RunState.from_dict(data["checkpoint"]), configs, sets, params, pool
	)
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
	return RunLoop.Reason.ILLEGAL


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

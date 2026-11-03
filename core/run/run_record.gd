class_name RunRecord
extends RefCounted
## What a save holds: the RunState where the loop last stood still, at a round's start
## or a Set's end, and the player's commands since. The loop is deterministic, so
## replaying the commands on that state rebuilds any moment in between exactly.

var checkpoint: Dictionary = {}
var commands: Array[Dictionary] = []


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
		var reason: RunLoop.Reason = _replay(loop, command)
		assert(reason == RunLoop.Reason.OK, "A saved command no longer applies")
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

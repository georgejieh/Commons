class_name BotPlay
extends RefCounted
## A bot's decision on its turn. A pass is a pass pattern.

var pattern: Pattern
var rationale: BotRationale.Code


func _init(chosen: Pattern, why: BotRationale.Code = BotRationale.Code.NONE) -> void:
	pattern = chosen
	rationale = why


func is_pass() -> bool:
	return pattern.type == Pattern.Type.PASS

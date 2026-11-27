class_name BotPlay
extends RefCounted
## A bot's decision on its turn. A pass is a pass pattern.

## The play the bot chose; a pass pattern when it passes.
var pattern: Pattern
## Which rule picked the play, for tests; NONE when no rule is recorded.
var rationale: BotRationale.Code


func _init(chosen: Pattern, why: BotRationale.Code = BotRationale.Code.NONE) -> void:
	pattern = chosen
	rationale = why


## True when the bot passes instead of playing cards.
func is_pass() -> bool:
	return pattern.type == Pattern.Type.PASS

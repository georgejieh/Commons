class_name Classification
extends RefCounted
## The classifier's answer: a Pattern, or null with a reason code.

enum Reason {
	OK,
	EMPTY,
	UNKNOWN_SHAPE,
	CHAIN_TOO_SHORT,
	UNCHAINABLE_RANK,
	BAD_KICKERS,
	BAD_WINGS,
	ROCKET_AS_KICKER,
}

var pattern: Pattern
var reason: Reason


func _init(result: Pattern, why: Reason) -> void:
	pattern = result
	reason = why


func is_valid() -> bool:
	return reason == Reason.OK

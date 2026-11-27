class_name Classification
extends RefCounted
## The classifier's answer: a Pattern, or null with a reason code.

## Why the cards read as no play, or OK when they do.
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

## The play the cards read as, or null when reason is not OK.
var pattern: Pattern
## OK, or why the cards make no legal play.
var reason: Reason


func _init(result: Pattern, why: Reason) -> void:
	pattern = result
	reason = why


## True when the cards read as a legal play.
func is_valid() -> bool:
	return reason == Reason.OK

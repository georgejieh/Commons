class_name BotBudget
extends RefCounted
## How long a decision may take. The clock comes from outside, because core has no
## time source. With no clock the budget never expires, so decisions stay repeatable.

const NO_LIMIT: int = 0

var _clock: Callable
var _deadline_usec: int = NO_LIMIT


## The clock takes no arguments and returns microseconds.
func _init(limit_usec: int = NO_LIMIT, clock: Callable = Callable()) -> void:
	_clock = clock
	if limit_usec != NO_LIMIT and clock.is_valid():
		_deadline_usec = clock.call() + limit_usec


static func unlimited() -> BotBudget:
	return BotBudget.new()


func is_expired() -> bool:
	return _deadline_usec != NO_LIMIT and _clock.call() >= _deadline_usec

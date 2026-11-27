class_name BotBudget
extends RefCounted
## How long a decision may take. The clock comes from outside, because core has no
## time source. With no clock the budget never expires, so decisions stay repeatable.

## The limit of a budget that never expires; also the deadline of one given no clock.
const NO_LIMIT: int = 0

var _clock: Callable
var _deadline_usec: int = NO_LIMIT


## The clock takes no arguments and returns microseconds.
func _init(limit_usec: int = NO_LIMIT, clock: Callable = Callable()) -> void:
	_clock = clock
	if limit_usec != NO_LIMIT and clock.is_valid():
		_deadline_usec = clock.call() + limit_usec


## A budget that never expires, so a decision made under it is repeatable.
static func unlimited() -> BotBudget:
	return BotBudget.new()


## True once the clock has reached the deadline; always false for a budget with no limit.
func is_expired() -> bool:
	return _deadline_usec != NO_LIMIT and _clock.call() >= _deadline_usec

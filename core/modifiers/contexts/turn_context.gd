class_name TurnContext
extends RefCounted
## Passed to the turn taken hook after each real play or pass in a round, and never for
## a preview, so an effect may count what it sees here in its own CadreMemo.

var seat: int
var landlord: int
## The play, or null for a pass.
var pattern: Pattern
## Cards left in the seat's hand after the turn.
var cards_left: int
## The run's player, whose Resentment and coupons a hook may raise.
var player: int
## Resentment and coupons to add to the player, to edit.
var resentment: int = 0
var coupons: int = 0


func _init(
	seat_value: int,
	landlord_value: int,
	pattern_value: Pattern,
	cards_left_value: int,
	player_value: int,
) -> void:
	seat = seat_value
	landlord = landlord_value
	pattern = pattern_value
	cards_left = cards_left_value
	player = player_value


func is_pass() -> bool:
	return pattern == null


## True for a Bomb or a Rocket.
func is_bomb() -> bool:
	if pattern == null:
		return false
	return pattern.type == Pattern.Type.BOMB or pattern.type == Pattern.Type.ROCKET

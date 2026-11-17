class_name NeedContext
extends RefCounted
## Passed to the need settled hook once a round's Commons is split and its audit done
## (ADR 0032): what the player declared against the true need, and whose lies the audit
## caught.

## What the player declared when they declared as a peasant, else NOT_DECLARED.
const NOT_DECLARED: int = -1

var player: int
var landlord: int
var declared: int
var true_need: int
## Every seat the audit caught in a lie this split, the player's own included.
var caught: Array[int] = []
## Resentment the player loses and coupons the player earns, to edit.
var resentment_fall: int = 0
var coupons: int = 0


func _init(
	player_value: int,
	landlord_value: int,
	declared_value: int,
	true_need_value: int,
	caught_value: Array[int],
) -> void:
	player = player_value
	landlord = landlord_value
	declared = declared_value
	true_need = true_need_value
	caught = caught_value.duplicate()


## True when the player declared as a peasant and claimed no more than the true need.
func declared_honestly() -> bool:
	return declared != NOT_DECLARED and declared <= true_need


## The villagers the audit caught: every caught seat but the player's.
func caught_villagers() -> int:
	return caught.filter(func(seat: int) -> bool: return seat != player).size()

class_name Decomposition
extends RefCounted
## One best way to split a hand into plays.

## The plays the hand is split into.
var groups: Array[Pattern]
## How many singles below a ten, in the seat's order, the split leaves as plays of their own.
var low_singles: int


func _init(best_groups: Array[Pattern], singles_left_low: int) -> void:
	groups = best_groups
	low_singles = singles_left_low


## How many plays the split takes to empty the hand. For tests.
func hands() -> int:
	return groups.size()

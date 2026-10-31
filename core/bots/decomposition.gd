class_name Decomposition
extends RefCounted
## One best way to split a hand into plays.

var groups: Array[Pattern]
var low_singles: int


func _init(best_groups: Array[Pattern], singles_left_low: int) -> void:
	groups = best_groups
	low_singles = singles_left_low


func hands() -> int:
	return groups.size()

class_name SetContext
extends RefCounted
## Passed to the Set end hook.

## The index of the Set that has just ended.
var set_index: int
## True when the Set's Quota was met.
var target_met: bool
## The player's coupons before the Quota pays.
var coupons: int = 0
## Coupons to add to the player's, to edit.
var add_coupons: int = 0
## The steps a met Quota beat its target by, 0 for a missed one (ADR 0032).
var over_steps: int = 0
## Resentment to add for those steps, to edit.
var add_resentment: int = 0


func _init(
	set_index_value: int,
	target_met_value: bool,
) -> void:
	set_index = set_index_value
	target_met = target_met_value

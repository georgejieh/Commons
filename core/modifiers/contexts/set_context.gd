class_name SetContext
extends RefCounted
## Passed to the Set end hook.

var set_index: int
var target_met: bool
## The player's coupons before the Quota pays, and coupons to add to them, to edit.
var coupons: int = 0
var add_coupons: int = 0
## The steps a met Quota beat its target by, 0 for a missed one, and Resentment to add
## for them, to edit (ADR 0032).
var over_steps: int = 0
var add_resentment: int = 0


func _init(
	set_index_value: int,
	target_met_value: bool,
) -> void:
	set_index = set_index_value
	target_met = target_met_value

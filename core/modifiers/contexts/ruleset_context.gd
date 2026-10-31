class_name RulesetContext
extends RefCounted
## Passed to the build ruleset hook.

## The seat being built.
var seat: int
var landlord: int
## A private copy to edit.
var params: RuleParams


func _init(
	seat_value: int,
	landlord_value: int,
	params_value: RuleParams,
) -> void:
	seat = seat_value
	landlord = landlord_value
	params = params_value

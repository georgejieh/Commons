class_name SetContext
extends RefCounted
## Passed to the Set end hook.

var set_index: int
var target_met: bool


func _init(
	set_index_value: int,
	target_met_value: bool,
) -> void:
	set_index = set_index_value
	target_met = target_met_value

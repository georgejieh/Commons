class_name MeterContext
extends RefCounted
## Passed to the meter change hook.

var meter: String
## The change, to edit.
var delta: int


func _init(
	meter_value: String,
	delta_value: int,
) -> void:
	meter = meter_value
	delta = delta_value

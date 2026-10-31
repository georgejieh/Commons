class_name ShopContext
extends RefCounted
## Passed to the shop open hook.

var seat: int


func _init(
	seat_value: int,
) -> void:
	seat = seat_value

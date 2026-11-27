class_name ShopContext
extends RefCounted
## Passed to the shop open hook.

var seat: int
## Cadres the state store shows fewer this visit, to edit (Short Supply, ADR 0023).
var cadre_cut: int = 0
## Black market rerolls this visit that cost nothing, to edit (Back Door, ADR 0032).
var free_market_rerolls: int = 0


func _init(
	seat_value: int,
) -> void:
	seat = seat_value

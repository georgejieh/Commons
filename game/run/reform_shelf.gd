class_name ReformShelf
extends RefCounted
## The state store's Reform for a screen to read (ADR 0021): what is offered, at what
## price, and whether it can be bought now. Buying goes through the run controller.

var _counter: ReformCounter


func _init(counter: ReformCounter) -> void:
	_counter = counter


## Reform IDs per slot, an empty ID for one already enacted.
func stock() -> Array[String]:
	return _counter.stock()


## The price in coupons of the Reform in slot.
func price(slot: int) -> int:
	return _counter.price(slot)


## True when the Reform in slot can be enacted now.
func can_buy(slot: int) -> bool:
	return _counter.check(slot) == RunShop.Reason.OK

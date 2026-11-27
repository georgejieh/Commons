class_name CampaignShelf
extends RefCounted
## A shop's Campaigns for a screen to read (ADR 0021): what is offered, at what price,
## and whether it can be bought now. Buying goes through the run controller.

var _counter: CampaignCounter


func _init(counter: CampaignCounter) -> void:
	_counter = counter


## Campaign IDs per slot, an empty ID for one already bought.
func stock() -> Array[String]:
	return _counter.stock()


## The price in coupons of the Campaign in slot.
func price(slot: int) -> int:
	return _counter.price(slot)


## True when the Campaign in slot can be bought now.
func can_buy(slot: int) -> bool:
	return _counter.check(slot) == RunShop.Reason.OK


## True for a Campaign sold back this visit, which cannot be bought until the next.
func is_sold_back(slot: int) -> bool:
	return _counter.check(slot) == RunShop.Reason.SOLD_BACK


## True when the player already holds as many Campaigns as they can.
func is_full() -> bool:
	return not _counter.has_room()

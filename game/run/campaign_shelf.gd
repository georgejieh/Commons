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


func price(slot: int) -> int:
	return _counter.price(slot)


func can_buy(slot: int) -> bool:
	return _counter.check(slot) == RunShop.Reason.OK


## True when the player already holds as many Campaigns as they can.
func is_full() -> bool:
	return not _counter.has_room()

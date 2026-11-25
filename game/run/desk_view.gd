class_name DeskView
extends RefCounted
## A shop's desk as a screen reads it (ADR 0041): whether it marks a card now, whether it
## has marked one this visit, the enhancement it gives or whether it stamps instead, its
## price, and why it would refuse a card. It only reads; a use goes through
## RunController.mark_card.

var _desk: MarkDesk
var _state: RunState


func _init(desk: MarkDesk, state: RunState) -> void:
	_desk = desk
	_state = state


func is_open() -> bool:
	return _desk.is_open


func used() -> bool:
	return _desk.used()


func offer() -> String:
	return _desk.offer


func stamps() -> bool:
	return _desk.stamps()


func price() -> int:
	return _desk.price()


func coupons() -> int:
	return _state.coupons


## True while the desk is open, unused and the coupons cover its price.
func affordable() -> bool:
	return is_open() and not used() and _state.coupons >= price()


## Why the desk would refuse the deck card, as the key of the words that say so, or ""
## when it would mark it.
func refusal(card_id: int) -> String:
	match _desk.check(card_id, RunLoop.PLAYER):
		MarkDesk.Reason.OK:
			return ""
		MarkDesk.Reason.TOO_POOR:
			return "deck.refused.poor"
		MarkDesk.Reason.ALREADY_MARKED:
			return "deck.refused.stamped" if stamps() else "deck.refused.marked"
	return "deck.refused.used"

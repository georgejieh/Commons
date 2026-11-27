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


## True when the desk marks a card this visit.
func is_open() -> bool:
	return _desk.is_open


## True once the desk has marked a card this visit.
func used() -> bool:
	return _desk.used()


## The enhancement on offer, or CardInstance.NO_ID at a desk that stamps.
func offer() -> String:
	return _desk.offer


## True at the desk that stamps cards rather than enhancing them.
func stamps() -> bool:
	return _desk.stamps()


## What the desk charges now in coupons, under any raise the books made.
func price() -> int:
	return _desk.price()


## The household's coupons now, to set against the price.
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

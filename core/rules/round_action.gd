class_name RoundAction
extends RefCounted
## What a seat does on its turn. No cards means a pass.

var seat: int
var card_ids: Array[int]


func _init(acting_seat: int, cards: Array[int] = []) -> void:
	seat = acting_seat
	card_ids = cards


static func from_cards(acting_seat: int, cards: Array[CardInstance]) -> RoundAction:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return RoundAction.new(acting_seat, ids)

class_name RoundAction
extends RefCounted
## What a seat does on its turn. No cards means a pass. A play names its cards and may
## name its reading (ADR 0029); with none, the strongest reading the round allows stands,
## which is the only one unless a wild card is among the cards.

var seat: int
var card_ids: Array[int]
var reading: Pattern = null


func _init(acting_seat: int, cards: Array[int] = []) -> void:
	seat = acting_seat
	card_ids = cards


static func from_cards(acting_seat: int, cards: Array[CardInstance]) -> RoundAction:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return RoundAction.new(acting_seat, ids)

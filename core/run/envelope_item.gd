class_name EnvelopeItem
extends RefCounted
## One choice in an open envelope (ADR 0021): a Directive or a Campaign by its ID, or a
## new plot card by its rank and suit, which carries the mark its kind names.

var content: EnvelopeDef.Content
## The Directive's or Campaign's ID; empty for a plot card.
var item_id: String = ""
## A plot card's rank and suit; Ranks.INVALID and Deck.NO_SUIT for anything else.
var rank: int = Ranks.INVALID
var suit: int = Deck.NO_SUIT


func _init(
	kind: EnvelopeDef.Content, id: String = "", card_rank: int = Ranks.INVALID, card_suit: int = -1
) -> void:
	content = kind
	item_id = id
	rank = card_rank
	suit = card_suit


## True for a plot card, stamped or Model.
func is_card() -> bool:
	return content == EnvelopeDef.Content.STAMPED_CARD or content == EnvelopeDef.Content.MODEL_CARD


## The same item: no envelope shows one twice.
func same_as(other: EnvelopeItem) -> bool:
	return (
		content == other.content
		and item_id == other.item_id
		and rank == other.rank
		and suit == other.suit
	)


func copy() -> EnvelopeItem:
	return EnvelopeItem.new(content, item_id, rank, suit)

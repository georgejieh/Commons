class_name EnvelopeItem
extends RefCounted
## One choice in an open envelope (ADR 0021): a Directive or a Campaign by its ID, or a
## new card by its rank and suit: a plot card carrying the mark its kind names, or a card
## for the communal deck with its enhancement or none (ADR 0042).

var content: EnvelopeDef.Content
## The Directive's or Campaign's ID; empty for a card.
var item_id: String = ""
## A card's rank and suit; Ranks.INVALID and Deck.NO_SUIT for anything else.
var rank: int = Ranks.INVALID
var suit: int = Deck.NO_SUIT
## A deck card's enhancement, or CardInstance.NO_ID.
var enhancement: String = CardInstance.NO_ID


func _init(
	kind: EnvelopeDef.Content,
	id: String = "",
	card_rank: int = Ranks.INVALID,
	card_suit: int = Deck.NO_SUIT,
	card_mark: String = CardInstance.NO_ID
) -> void:
	content = kind
	item_id = id
	rank = card_rank
	suit = card_suit
	enhancement = card_mark


## True for a plot card, stamped or Model.
func is_plot_card() -> bool:
	return content == EnvelopeDef.Content.STAMPED_CARD or content == EnvelopeDef.Content.MODEL_CARD


## True for a card for the communal deck, marked or not.
func is_deck_card() -> bool:
	return (
		content == EnvelopeDef.Content.DECK_CARD or content == EnvelopeDef.Content.MARKED_DECK_CARD
	)


## The same item: no envelope shows one twice.
func same_as(other: EnvelopeItem) -> bool:
	return (
		content == other.content
		and item_id == other.item_id
		and rank == other.rank
		and suit == other.suit
		and enhancement == other.enhancement
	)


func copy() -> EnvelopeItem:
	return EnvelopeItem.new(content, item_id, rank, suit, enhancement)

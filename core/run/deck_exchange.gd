class_name DeckExchange
extends RefCounted
## The rules every exchange of a communal deck card keeps (ADR 0042): one card in, one
## out, so the deck always holds 54. The card that comes in takes the leaving card's slot
## for the rest of the run, with its own rank, suit and enhancement; the leaving card is
## gone, its marks with it. No joker is offered and none can leave, so the Rocket stays
## possible and the deck never holds a third joker. A rank may not go past the data's
## most copies, and one at that most is never offered; a rank may be emptied.


## Why a card of rank could not come into the deck now, or OK.
static func check_in(state: RunState, run: RunParams, rank: int) -> RunShop.Reason:
	if state.deck.rank_counts()[rank] >= run.deck_rank_most:
		return RunShop.Reason.AT_MOST
	return RunShop.Reason.OK


## Why the card in slot could not leave the deck, or OK.
static func check_out(state: RunState, slot: int) -> RunShop.Reason:
	if slot < 0 or slot >= Deck.SIZE:
		return RunShop.Reason.NO_SUCH_CARD
	if state.deck.rank_of(slot) >= Ranks.SMALL_JOKER:
		return RunShop.Reason.JOKER
	return RunShop.Reason.OK


## The ranks of offered that the deck has room for, in their order.
static func open_ranks(state: RunState, run: RunParams, offered: Array[int]) -> Array[int]:
	var counts: PackedByteArray = state.deck.rank_counts()
	var open: Array[int] = []
	for rank: int in offered:
		if rank < Ranks.SMALL_JOKER and counts[rank] < run.deck_rank_most:
			open.append(rank)
	return open


## Puts the card of rank and suit, with its enhancement or none, in the slot for the rest
## of the run. The caller has checked both sides.
static func apply(state: RunState, slot: int, rank: int, suit: int, enhancement: String) -> void:
	state.deck.replace(slot, rank, suit)
	state.card_marks.stamps.erase(slot)
	state.card_marks.enhancements.erase(slot)
	if enhancement != CardInstance.NO_ID:
		state.card_marks.enhancements[slot] = enhancement

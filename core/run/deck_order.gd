class_name DeckOrder
extends RefCounted
## Unplanned Economy's deal (ADR 0021): between the rounds of a Quota the deck is gathered
## as the last round left it and cut, not shuffled. gather() takes the cards in the order
## they were played, then each seat's unplayed cards in seat order, then the unplayed
## kitty, keeping deck cards only. A plot card swapped into a hand is left out, and a
## deck card a swap took out of the round is put back at the end, in ID order (ADR 0038):
## the order always holds every deck card exactly once. deal() cuts it once at a point
## drawn on the deal stream and deals it in order, as Dealer deals: seat 0's hand, seat
## 1's, seat 2's, then the kitty.


## The deck IDs a finished round leaves, in gathering order.
static func gather(round_state: RoundState) -> Array[int]:
	var kitty: Array[int] = []
	var order: Array[int] = []
	for event: RoundEvent in round_state.events():
		if event.type == RoundEvent.Type.KITTY_TAKEN:
			kitty.assign(event.card_ids)
		elif event.type == RoundEvent.Type.PLAYED:
			order.append_array(event.card_ids)
	for seat: int in Seats.COUNT:
		for card: CardInstance in round_state.view_for(seat).own_cards:
			if not kitty.has(card.id()):
				order.append(card.id())
	order.append_array(kitty)
	return whole(order)


## The deck cards of order, each once in its first place, then any deck card it lacks in
## ID order.
static func whole(order: Array[int]) -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	var kept: Array[int] = []
	for card_id: int in order:
		if card_id >= 0 and card_id < Deck.SIZE and not seen.has(card_id):
			seen[card_id] = true
			kept.append(card_id)
	for deck_id: int in Deck.SIZE:
		if not seen.has(deck_id):
			kept.append(deck_id)
	return kept


## order with its first at cards moved to the bottom, as a cut does.
static func cut(order: Array[int], at: int) -> Array[int]:
	return order.slice(at) + order.slice(0, at)


## Deals the gathered order after one cut drawn on stream, with the saved marks put back.
static func deal(order: Array[int], marks: CardMarks, stream: RandomStream) -> DealResult:
	var cut_order: Array[int] = cut(order, stream.next_int(1, order.size() - 1))
	var cards: Array[CardInstance] = []
	for deck_id: int in cut_order:
		cards.append(CardInstance.from_deck_id(deck_id))
	marks.apply(cards)
	return Dealer.deal_in_order(cards)


## A saved order is empty, or holds every deck card exactly once.
static func is_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var order: Array = value
	if order.is_empty():
		return true
	if order.size() != Deck.SIZE:
		return false
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in order:
		if not (entry is int or entry is float):
			return false
		var card_id: int = int(entry)
		if card_id < 0 or card_id >= Deck.SIZE or seen.has(card_id):
			return false
		seen[card_id] = true
	return true

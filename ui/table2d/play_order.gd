class_name PlayOrder
extends RefCounted
## The order a play's cards lie in on the trick: the body of its reading first, low to high
## with each rank's cards together, then its kickers low to high. A wild card standing in
## lies with the rank it stands for, after the natural cards of that rank (ADR 0029). The
## run hands the cards over in whatever order they were chosen, a villager's by value and
## the player's by the hand, so the pile sorts them itself.  Ranks here are printed ranks,
## never a seat's rank order: a chain is a run of printed ranks (Classifier) whatever a
## Cadre or debuff does to how ranks compare, so a pair run reads 5 5 6 6 7 7 at every
## seat.


## The indices of cards in the order they lie, as reading reads them; with no reading,
## low to high by printed rank. stands is what PlayPlacement.stands_for gives for the cards
## under reading, when the caller has worked it out already.
static func arrange(
	cards: Array[CardInstance], reading: Pattern = null, stands: PackedByteArray = PackedByteArray()
) -> Array[int]:
	if reading == null:
		stands = PackedByteArray()
		for card: CardInstance in cards:
			stands.append(card.base_rank())
	elif stands.is_empty():
		stands = PlayPlacement.stands_for(cards, reading)
	var keys: Array[Array] = []
	for index: int in cards.size():
		var card: CardInstance = cards[index]
		var kicker: int = 0
		if reading != null and not PlayPlacement.is_body(stands[index], reading):
			kicker = 1
		var stand_in: int = 1 if stands[index] != card.base_rank() else 0
		keys.append([kicker, stands[index], stand_in, card.suit(), card.id(), index])
	keys.sort_custom(_before)
	var order: Array[int] = []
	for key: Array in keys:
		order.append(int(key[-1]))
	return order


static func _before(a: Array, b: Array) -> bool:
	for at: int in a.size():
		if a[at] != b[at]:
			return a[at] < b[at]
	return false

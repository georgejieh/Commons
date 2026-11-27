class_name PlayPlacement
extends RefCounted
## Where a reading puts each physical card (ADR 0029): the rank each card stands for.
## Every natural card, and as many wild cards as the reading allows, stand for their own
## rank, lowest printed rank first and then lowest ID. The other wild cards stand in, in
## that same order, filling the body before the kickers, each from its lowest rank. With
## no stand-in every card stands for its printed rank.


## One rank per card, in the order of cards.
static func stands_for(cards: Array[CardInstance], pattern: Pattern) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	for card: CardInstance in cards:
		result.append(card.base_rank())
	if pattern.spent.is_empty():
		return result
	var open: PackedByteArray = pattern.counts()
	var order: Array[int] = []
	for index: int in cards.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return _placed_before(cards[a], cards[b]))
	var waiting: Array[int] = []
	for index: int in order:
		var rank: int = cards[index].base_rank()
		if open[rank] > 0:
			open[rank] -= 1
		else:
			waiting.append(index)
	var slots: PackedByteArray = _slots(pattern, open)
	for at: int in waiting.size():
		result[waiting[at]] = slots[at]
	return result


## True for a card the reading scores as body, not kicker. Every card of a rocket scores.
static func is_body(rank: int, pattern: Pattern) -> bool:
	if pattern.type == Pattern.Type.ROCKET:
		return true
	return rank >= pattern.main_rank and rank < pattern.main_rank + pattern.chain_length


## The open slots, body ranks first, then kicker ranks, each low to high.
static func _slots(pattern: Pattern, open: PackedByteArray) -> PackedByteArray:
	var body: PackedByteArray = PackedByteArray()
	var kickers: PackedByteArray = PackedByteArray()
	for rank: int in Ranks.COUNT:
		for _copy: int in open[rank]:
			if is_body(rank, pattern):
				body.append(rank)
			else:
				kickers.append(rank)
	body.append_array(kickers)
	return body


static func _placed_before(first: CardInstance, second: CardInstance) -> bool:
	if first.base_rank() != second.base_rank():
		return first.base_rank() < second.base_rank()
	return first.id() < second.id()

class_name Hand
extends RefCounted
## A hand's card instances plus rank counts and a present-rank bitmask, kept current
## in O(1). Rules and bot code read the counts and bitmask, never the instances.

var _cards: Array[CardInstance] = []
var _index_by_id: Dictionary[int, int] = {}
var _counts: PackedByteArray = PackedByteArray()
var _rank_mask: int = 0


func _init() -> void:
	_counts.resize(Ranks.COUNT)


## Returns false, changing nothing, if the card is already in the hand.
func add(card: CardInstance) -> bool:
	if _index_by_id.has(card.id):
		return false
	_index_by_id[card.id] = _cards.size()
	_cards.append(card)
	_counts[card.base_rank] += 1
	_rank_mask |= 1 << card.base_rank
	return true


## Removes and returns a card, or returns null if it is not in the hand.
## The last card fills the gap, so instance order is not preserved.
func remove(card_id: int) -> CardInstance:
	if not _index_by_id.has(card_id):
		return null
	var index: int = _index_by_id[card_id]
	var card: CardInstance = _cards[index]
	var last: CardInstance = _cards[-1]
	_cards[index] = last
	_index_by_id[last.id] = index
	_cards.resize(_cards.size() - 1)
	_index_by_id.erase(card_id)

	_counts[card.base_rank] -= 1
	if _counts[card.base_rank] == 0:
		_rank_mask &= ~(1 << card.base_rank)
	return card


func size() -> int:
	return _cards.size()


func has_card(card_id: int) -> bool:
	return _index_by_id.has(card_id)


func count_of(rank: int) -> int:
	return _counts[rank]


## Returns a copy, because packed arrays are shared by reference.
func counts() -> PackedByteArray:
	return _counts.duplicate()


func rank_mask() -> int:
	return _rank_mask


func cards() -> Array[CardInstance]:
	return _cards.duplicate()

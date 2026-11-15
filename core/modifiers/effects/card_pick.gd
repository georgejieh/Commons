class_name CardPick
extends RefCounted
## Picks a seat's highest or lowest cards by its own rank order, ties by card ID: the
## higher ID first among the highest, the lower among the lowest.


static func extremes(
	cards: Array[CardInstance], rank_map: PackedByteArray, highest: bool, count: int
) -> Array[int]:
	var left: Array[CardInstance] = cards.duplicate()
	var picked: Array[int] = []
	while picked.size() < count and not left.is_empty():
		var best: int = 0
		for index: int in range(1, left.size()):
			if _ahead(left[index], left[best], rank_map, highest):
				best = index
		picked.append(left[best].id())
		left.remove_at(best)
	return picked


static func _ahead(
	card: CardInstance, other: CardInstance, rank_map: PackedByteArray, highest: bool
) -> bool:
	var rank: int = rank_map[card.base_rank()]
	var other_rank: int = rank_map[other.base_rank()]
	if rank != other_rank:
		return rank > other_rank if highest else rank < other_rank
	return card.id() > other.id() if highest else card.id() < other.id()

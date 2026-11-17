class_name BalanceCards
extends RefCounted
## Card orderings the harness's choices share: by strength in the seat's rank order, then
## base rank, then ID, so every choice is the same for the same cards.


static func strength(card: CardInstance, rank_map: PackedByteArray) -> int:
	return rank_map[card.base_rank()] if card.base_rank() < rank_map.size() else card.base_rank()


## A copy of cards, weakest first when ascending, strongest first otherwise.
static func sorted(
	cards: Array[CardInstance], rank_map: PackedByteArray, ascending: bool
) -> Array[CardInstance]:
	var out: Array[CardInstance] = cards.duplicate()
	out.sort_custom(
		func(a: CardInstance, b: CardInstance) -> bool:
			var key_a: Vector3i = Vector3i(strength(a, rank_map), a.base_rank(), a.id())
			var key_b: Vector3i = Vector3i(strength(b, rank_map), b.base_rank(), b.id())
			return key_a < key_b if ascending else key_a > key_b
	)
	return out


## Counts per base rank.
static func counts(cards: Array[CardInstance]) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Ranks.COUNT)
	for card: CardInstance in cards:
		result[card.base_rank()] += 1
	return result


## The rank from 3 to 2 held most often in counts, the higher on a tie, or 2 for none.
static func most_held(counts_in: PackedByteArray) -> int:
	var best: int = Ranks.TWO
	var most: int = 0
	for rank: int in range(Ranks.THREE, Ranks.TWO + 1):
		if counts_in[rank] >= most and counts_in[rank] > 0:
			best = rank
			most = counts_in[rank]
	return best

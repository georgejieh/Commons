class_name AidChoice
extends RefCounted
## Which cards a villager hands its teammate under Mutual Aid (ADR 0021): its lowest
## cards that stand alone, a rank it holds once and no joker of a rocket, lowest by its
## own rank order and then by card ID. With too few of those it makes up the count from
## its lowest other cards. A plain rule, so a trade never needs a search.


## The IDs of the count cards the villager hands over, the loose lowest first and then the
## lowest of the rest; fewer when the hand holds fewer. Cards are ranked by rank_map.
static func choose(view: SeatView, rank_map: PackedByteArray, count: int) -> Array[int]:
	var loose: Array[CardInstance] = []
	var rest: Array[CardInstance] = []
	var rocket: bool = (
		view.own_counts[Ranks.SMALL_JOKER] > 0 and view.own_counts[Ranks.BIG_JOKER] > 0
	)
	for card: CardInstance in view.own_cards:
		var rank: int = card.base_rank()
		var alone: bool = view.own_counts[rank] == 1
		if alone and not (rocket and rank >= Ranks.SMALL_JOKER):
			loose.append(card)
		else:
			rest.append(card)
	var lowest_first: Callable = func(a: CardInstance, b: CardInstance) -> bool:
		return _below(a, b, rank_map)
	loose.sort_custom(lowest_first)
	rest.sort_custom(lowest_first)
	var chosen: Array[int] = []
	for card: CardInstance in loose + rest:
		if chosen.size() >= count:
			break
		chosen.append(card.id())
	return chosen


static func _below(a: CardInstance, b: CardInstance, rank_map: PackedByteArray) -> bool:
	var a_rank: int = rank_map[a.base_rank()]
	var b_rank: int = rank_map[b.base_rank()]
	if a_rank != b_rank:
		return a_rank < b_rank
	return a.id() < b.id()

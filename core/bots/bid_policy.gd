class_name BidPolicy
extends RefCounted
## Decides whether to claim the seat, from hand points against a threshold.

const BOMB_WIDTH: int = 4


static func hand_points(counts: PackedByteArray, table: BotTable, weights: BotWeights) -> float:
	var points: float = 0.0
	points += counts[Ranks.BIG_JOKER] * weights.big_joker_points
	points += counts[Ranks.SMALL_JOKER] * weights.small_joker_points
	points += counts[Ranks.TWO] * weights.two_points
	points += counts[Ranks.ACE] * weights.ace_points
	for rank: int in Ranks.TWO + 1:
		if counts[rank] >= BOMB_WIDTH:
			points += weights.bomb_points
	if counts[Ranks.SMALL_JOKER] > 0 and counts[Ranks.BIG_JOKER] > 0:
		points += weights.rocket_points
	return points + _shape_bonus(counts, table, weights)


static func threshold(is_grab: bool, is_last: bool, weights: BotWeights) -> float:
	var bar: float = weights.grab_threshold if is_grab else weights.call_threshold
	return bar * weights.last_bidder_factor if is_last else bar


static func _shape_bonus(counts: PackedByteArray, table: BotTable, weights: BotWeights) -> float:
	var search: HandDecomposer = HandDecomposer.new(table.rules, table.rank_map, weights.memo_cap)
	var hands: int = HandDecomposer.hands_in(search.score(counts))
	return maxf(0.0, weights.shape_par_hands - hands) * weights.shape_points

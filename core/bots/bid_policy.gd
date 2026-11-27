class_name BidPolicy
extends RefCounted
## Decides whether to claim the seat, from hand points against a threshold.


## A hand's worth in bid points: its jokers, 2s, aces, bombs, rocket and wild cards by the
## weights, and a bonus for a hand that empties in few plays. Counts are per rank.
static func hand_points(counts: PackedByteArray, table: BotTable, weights: BotWeights) -> float:
	var points: float = 0.0
	points += counts[Ranks.BIG_JOKER] * weights.big_joker_points
	points += counts[Ranks.SMALL_JOKER] * weights.small_joker_points
	points += counts[Ranks.TWO] * weights.two_points
	points += counts[Ranks.ACE] * weights.ace_points
	for rank: int in Ranks.TWO + 1:
		if counts[rank] >= Pattern.MIN_BOMB_WIDTH:
			points += weights.bomb_points
	if counts[Ranks.SMALL_JOKER] > 0 and counts[Ranks.BIG_JOKER] > 0:
		points += weights.rocket_points
	# A wild card can stand in for any rank (ADR 0029), so each one held counts as well.
	for rank: int in table.rules.wild_ranks():
		points += counts[rank] * weights.wild_card_points
	return points + _shape_bonus(counts, table, weights)


## The points a hand must reach to bid: the grab bar or the call bar, and for the last
## bidder that bar scaled by last_bidder_factor.
static func threshold(is_grab: bool, is_last: bool, weights: BotWeights) -> float:
	var bar: float = weights.grab_threshold if is_grab else weights.call_threshold
	return bar * weights.last_bidder_factor if is_last else bar


static func _shape_bonus(counts: PackedByteArray, table: BotTable, weights: BotWeights) -> float:
	var search: HandDecomposer = HandDecomposer.new(table.rules, table.rank_map, weights.memo_cap)
	var hands: int = HandDecomposer.hands_in(search.score(counts))
	return maxf(0.0, weights.shape_par_hands - hands) * weights.shape_points

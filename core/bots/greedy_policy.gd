class_name GreedyPolicy
extends RefCounted
## The Easy tier. Leads its lowest rank with as many cards as it can, and answers with the
## lowest play that beats the table. Bombs wait for an opponent about to go out.


static func choose(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig
) -> BotPlay:
	if view.public.current_play == null:
		return BotPlay.new(_lowest_longest(legal, table), BotRationale.Code.GREEDY)
	var landlord: int = view.public.landlord
	var fewest: int = BotPosition.NO_CARDS
	for other: int in Seats.COUNT:
		var rival: bool = other != view.seat and (view.seat == landlord or other == landlord)
		if rival and view.public.remaining[other] < fewest:
			fewest = view.public.remaining[other]
	var bombs_open: bool = fewest <= config.weights.block_cards
	var lowest: Pattern = null
	for move: Pattern in legal:
		var gated: bool = FollowPolicy.is_bomb(move) and not bombs_open
		if not gated and (lowest == null or _is_better_answer(move, lowest)):
			lowest = move
	if lowest == null:
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_NOTHING_BEATS)
	return BotPlay.new(lowest, BotRationale.Code.GREEDY)


## Plays of the same shape are ordered by key, and a bomb only ever answers last.
static func _is_better_answer(move: Pattern, other: Pattern) -> bool:
	if FollowPolicy.is_bomb(move) != FollowPolicy.is_bomb(other):
		return FollowPolicy.is_bomb(other)
	return move.key < other.key


static func _lowest_longest(legal: Array[Pattern], table: BotTable) -> Pattern:
	var best: Pattern = legal[0]
	for move: Pattern in legal:
		var rank: int = table.rank_map[move.main_rank]
		var best_rank: int = table.rank_map[best.main_rank]
		var lower: bool = rank < best_rank
		var longer: bool = rank == best_rank and move.card_count > best.card_count
		if (lower or longer) and not FollowPolicy.is_bomb(move):
			best = move
	return best

class_name LeadPolicy
extends RefCounted
## Chooses a lead, by the first rule that applies. Danger rules narrow the moves that the
## later rules may pick from.

const ONE_CARD: int = 1
const TWO_CARDS: int = 2
const SINGLE_WIDTH: int = 1
const PAIR_WIDTH: int = 2
const LOW_LIMIT_RANK: int = Ranks.TEN


static func choose(position: BotPosition, legal: Array[Pattern]) -> BotPlay:
	var whole: Pattern = position.going_out(legal)
	if whole != null:
		return BotPlay.new(whole, BotRationale.Code.GO_OUT)
	if position.forced_win():
		var forced: Pattern = _forced_lead(position, legal)
		if forced != null:
			return BotPlay.new(forced, BotRationale.Code.FORCED_WIN)
	var safe: Array[Pattern] = _safe_moves(position, legal)
	if position.teammate_cards <= TWO_CARDS:
		var feed: Pattern = _feed_teammate(position, safe)
		if feed != null:
			return BotPlay.new(feed, BotRationale.Code.FEED_TEAMMATE)
	var weakest: Pattern = _weakest_group(position, safe)
	if weakest != null:
		return BotPlay.new(weakest, BotRationale.Code.WEAKEST_GROUP)
	return BotPlay.new(_best_scored(position, safe), BotRationale.Code.BEST_SCORE)


## Controls first, and the group that can be beaten last.
static func _forced_lead(position: BotPosition, legal: Array[Pattern]) -> Pattern:
	for index: int in position.groups.size():
		if position.controls.flags[index]:
			var move: Pattern = _usable(position.groups[index], legal)
			if move != null:
				return move
	return null


## Keeps moves that an opponent on 1 or 2 cards can't simply go out over.
static func _safe_moves(position: BotPosition, legal: Array[Pattern]) -> Array[Pattern]:
	var moves: Array[Pattern] = legal
	if position.opponent_cards == ONE_CARD:
		moves = _without_low(position, moves, Pattern.Type.SINGLE, SINGLE_WIDTH)
	elif position.opponent_cards == TWO_CARDS:
		moves = _without_low(position, moves, Pattern.Type.PAIR, PAIR_WIDTH)
	return moves


## Drops plays of the type that unseen cards beat. With nothing else, plays the highest.
static func _without_low(
	position: BotPosition, moves: Array[Pattern], type: Pattern.Type, width: int
) -> Array[Pattern]:
	var kept: Array[Pattern] = []
	var highest: Pattern = null
	for move: Pattern in moves:
		if move.type != type:
			kept.append(move)
			continue
		if (
			highest == null
			or position.rank_of(move.main_rank) > position.rank_of(highest.main_rank)
		):
			highest = move
		if _is_top(position, move.main_rank, width):
			kept.append(move)
	if kept.is_empty() and highest != null:
		kept.append(highest)
	return kept


static func _is_top(position: BotPosition, rank: int, width: int) -> bool:
	for other: int in Ranks.COUNT:
		var could_answer: bool = position.unseen[other] >= width
		if could_answer and position.rank_of(other) > position.rank_of(rank):
			return false
	return true


static func _feed_teammate(position: BotPosition, moves: Array[Pattern]) -> Pattern:
	var wanted: Pattern.Type = Pattern.Type.SINGLE
	if position.teammate_cards == TWO_CARDS:
		wanted = Pattern.Type.PAIR
	var lowest: Pattern = null
	for move: Pattern in moves:
		if move.type == wanted and _is_lower(position, move, lowest):
			lowest = move
	if lowest == null and wanted == Pattern.Type.PAIR:
		for move: Pattern in moves:
			if move.type == Pattern.Type.SINGLE and _is_lower(position, move, lowest):
				lowest = move
	return lowest


## Most low cards shed first, then the weakest.
static func _weakest_group(position: BotPosition, moves: Array[Pattern]) -> Pattern:
	var best: Pattern = null
	var best_low: int = -1
	for index: int in position.groups.size():
		if position.controls.flags[index]:
			continue
		var move: Pattern = _usable(position.groups[index], moves)
		if move == null:
			continue
		var low: int = _low_cards(position, move)
		if low > best_low or (low == best_low and _is_lower(position, move, best)):
			best = move
			best_low = low
	return best


static func _low_cards(position: BotPosition, move: Pattern) -> int:
	var counts: PackedByteArray = move.counts()
	var low: int = 0
	for rank: int in Ranks.COUNT:
		if position.rank_of(rank) < position.rank_of(LOW_LIMIT_RANK):
			low += counts[rank]
	return low


static func _is_lower(position: BotPosition, move: Pattern, other: Pattern) -> bool:
	if other == null:
		return true
	return position.rank_of(move.main_rank) < position.rank_of(other.main_rank)


## The group as a legal move. A 2 or joker never rides as a kicker, so a group carrying
## one is played bare.
static func _usable(group: Pattern, moves: Array[Pattern]) -> Pattern:
	var wanted: Pattern = group
	for kicker: int in group.kicker_ranks:
		if kicker >= Ranks.TWO:
			wanted = _bare(group)
			break
	for move: Pattern in moves:
		if move.equals(wanted):
			return move
	return null


static func _bare(group: Pattern) -> Pattern:
	var type: Pattern.Type = Pattern.Type.TRIO
	if group.chain_length > 1:
		type = Pattern.Type.AIRPLANE
	var body: int = group.card_count - group.kicker_ranks.size()
	var effective: int = group.key & ((1 << Pattern.KEY_RANK_BITS) - 1)
	var kickers: PackedByteArray = PackedByteArray()
	return Pattern.new(type, group.main_rank, group.chain_length, body, kickers, effective)


static func _best_scored(position: BotPosition, moves: Array[Pattern]) -> Pattern:
	var best: Pattern = moves[0]
	var best_score: float = -INF
	for move: Pattern in moves:
		var score: float = position.scorer.score_play(move)
		if score > best_score:
			best_score = score
			best = move
	return best

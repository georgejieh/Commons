class_name FollowPolicy
extends RefCounted
## Chooses a response to the play on the table.


static func choose(position: BotPosition, legal: Array[Pattern]) -> BotPlay:
	var whole: Pattern = position.going_out(legal)
	if whole != null:
		return BotPlay.new(whole, BotRationale.Code.GO_OUT)
	if (
		position.trick_owner() == position.teammate
		and position.roll() < position.config.cooperation
	):
		return _on_teammate(position, legal)
	if position.forced_win() and position.config.reads_the_table():
		var take: Pattern = _take_with_control(position, legal)
		if take != null:
			return BotPlay.new(take, BotRationale.Code.FORCED_WIN)
	var endgame: bool = position.opponent_cards <= position.config.weights.block_cards
	if endgame and position.config.reads_the_table():
		var stop: Pattern = _block(position, legal)
		if stop != null:
			return BotPlay.new(stop, BotRationale.Code.BLOCK_OPPONENT)
	var block: Pattern = SeatRole.block_landlord_single(position, legal)
	if block != null:
		return BotPlay.new(block, BotRationale.Code.BLOCK_LANDLORD)
	return _best_response(position, SeatRole.saved_for_later(position, _ungated(position, legal)))


## Passes, unless this is the upstream seat and the landlord could take the card cheaply.
static func _on_teammate(position: BotPosition, legal: Array[Pattern]) -> BotPlay:
	var play: Pattern = position.view.public.current_play
	var weights: BotWeights = position.config.weights
	var weak: bool = position.rank_of(play.main_rank) < weights.weak_teammate_rank
	if (
		position.plays_a_role()
		and position.is_upstream()
		and weak
		and play.type == Pattern.Type.SINGLE
	):
		for move: Pattern in legal:
			var high_enough: bool = position.rank_of(move.main_rank) >= weights.block_low_rank
			if move.type == play.type and high_enough and move.main_rank < Ranks.TWO:
				return BotPlay.new(move, BotRationale.Code.BLOCK_FOR_TEAMMATE)
	return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_TEAMMATE)


## A control from the best split that answers the table keeps the forced win going.
static func _take_with_control(position: BotPosition, legal: Array[Pattern]) -> Pattern:
	for index: int in position.groups.size():
		if position.controls.flags[index]:
			for move: Pattern in legal:
				if move.equals(position.groups[index]):
					return move
	return null


## The cheapest answer nothing unseen beats, then the strongest, then the lowest bomb.
static func _block(position: BotPosition, legal: Array[Pattern]) -> Pattern:
	var strongest: Pattern = null
	var safest: Pattern = null
	var bomb: Pattern = null
	var groups: Array[Pattern] = []
	for move: Pattern in legal:
		if is_bomb(move):
			if bomb == null:
				bomb = move
			continue
		groups.assign([move])
		var answers: Controls = position.read_groups(groups)
		if answers.flags[0] and (safest == null or move.key < safest.key):
			safest = move
		if strongest == null or move.key > strongest.key:
			strongest = move
	if safest != null:
		return safest
	return strongest if strongest != null else bomb


## Keeps the moves whose gates are open.
static func _ungated(position: BotPosition, legal: Array[Pattern]) -> Array[Pattern]:
	var open_high: bool = _high_cards_open(position)
	var open_bombs: bool = _bombs_open(position)
	var kept: Array[Pattern] = []
	for move: Pattern in legal:
		if is_bomb(move):
			if open_bombs:
				kept.append(move)
		elif move.type != Pattern.Type.SINGLE or move.main_rank < Ranks.TWO or open_high:
			kept.append(move)
	return kept


static func _high_cards_open(position: BotPosition) -> bool:
	var landlord: int = position.view.public.landlord
	var blocks_landlord: bool = not position.is_landlord() and position.trick_owner() == landlord
	var stops_opponent: bool = position.opponent_cards <= position.config.weights.block_cards
	return blocks_landlord or stops_opponent or position.forced_win()


static func _bombs_open(position: BotPosition) -> bool:
	if position.forced_win() or position.opponent_cards <= position.config.weights.block_cards:
		return true
	var landlord_cards: int = position.view.public.remaining[position.view.public.landlord]
	var bar: float = position.config.weights.runaway_cards + position.config.bomb_shift
	var runaway: bool = landlord_cards <= bar
	return runaway and not position.is_landlord()


static func is_bomb(move: Pattern) -> bool:
	return move.type == Pattern.Type.BOMB or move.type == Pattern.Type.ROCKET


## Best score change, lower rank on ties, and a pass when nothing beats passing.
static func _best_response(position: BotPosition, moves: Array[Pattern]) -> BotPlay:
	var best: Pattern = null
	var best_score: float = position.scorer.score_pass()
	var owner: int = position.trick_owner()
	var spite: float = position.config.grudge * position.config.memory[owner]
	for move: Pattern in moves:
		var score: float = position.scorer.score_play(move) + spite
		var ties: bool = best != null and is_equal_approx(score, best_score)
		if score > best_score or (ties and move.key < best.key):
			best = move
			best_score = score
	if best == null:
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_NOTHING_BEATS)
	return BotPlay.new(best, BotRationale.Code.BEST_SCORE)

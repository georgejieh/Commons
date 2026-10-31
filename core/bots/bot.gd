class_name Bot
extends RefCounted
## The only way the game asks a bot for anything. Three pure functions, each with a
## time budget. A bot sees its SeatView and the legal moves, never another hand.


## True claims the landlord seat. counts is the bot's own dealt hand.
static func decide_bid(_counts: PackedByteArray, _config: BotConfig, _budget: BotBudget) -> bool:
	return false


## legal is what MoveGenerator lists. Returns a pass only when following.
static func decide_play(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig, _budget: BotBudget
) -> BotPlay:
	if legal.is_empty():
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_NOTHING_BEATS)
	var scorer: CandidateScorer = CandidateScorer.new(view.own_counts, table, config.weights)
	var following: bool = view.public.current_play != null
	var best_move: Pattern = Pattern.pass_play() if following else legal[0]
	var best_score: float = scorer.score_pass() if following else -INF
	for move: Pattern in legal:
		var score: float = scorer.score_play(move)
		if score > best_score:
			best_score = score
			best_move = move
	return BotPlay.new(best_move, BotRationale.Code.BEST_SCORE)


## Returns the need the bot declares before a Commons split.
static func declare_need(true_need: int, _config: BotConfig, _budget: BotBudget) -> int:
	return true_need

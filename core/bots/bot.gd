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
	var position: BotPosition = BotPosition.new(view, table, config, scorer)
	if view.public.current_play == null:
		return LeadPolicy.choose(position, legal)
	return FollowPolicy.choose(position, legal)


## Returns the need the bot declares before a Commons split.
static func declare_need(true_need: int, _config: BotConfig, _budget: BotBudget) -> int:
	return true_need

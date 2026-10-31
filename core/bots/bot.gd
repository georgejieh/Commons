class_name Bot
extends RefCounted
## The only way the game asks a bot for anything. Three pure functions, each with a
## time budget. A bot sees its SeatView and the legal moves, never another hand.


## True claims the landlord seat. counts is the bot's own dealt hand.
static func decide_bid(_counts: PackedByteArray, _budget: BotBudget) -> bool:
	return false


## legal is what MoveGenerator lists. Returns a pass only when following.
static func decide_play(
	_view: SeatView, legal: Array[Pattern], _table: BotTable, _budget: BotBudget
) -> BotPlay:
	if legal.is_empty():
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_NOTHING_BEATS)
	return BotPlay.new(legal[0], BotRationale.Code.LOWEST_BEATING_PLAY)


## Returns the need the bot declares before a Commons split.
static func declare_need(true_need: int, _budget: BotBudget) -> int:
	return true_need

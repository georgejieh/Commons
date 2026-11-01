class_name Bot
extends RefCounted
## The only way the game asks a bot for anything. Three pure functions, each with a
## time budget. A bot sees its SeatView and the legal moves, never another hand.


## True claims the landlord seat. counts is the bot's own dealt hand.
static func decide_bid(
	counts: PackedByteArray,
	is_grab: bool,
	is_last: bool,
	table: BotTable,
	config: BotConfig,
	_budget: BotBudget
) -> bool:
	var points: float = BidPolicy.hand_points(counts, table, config.weights)
	return points >= BidPolicy.threshold(is_grab, is_last, config.weights) - config.ambition


## legal is what MoveGenerator lists. Returns a pass only when following.
static func decide_play(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig, budget: BotBudget
) -> BotPlay:
	if legal.is_empty():
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_NOTHING_BEATS)
	if config.tier == BotConfig.Tier.EASY:
		return GreedyPolicy.choose(view, legal, config)
	var job: BotSearchJob = search_job(view, legal, table, config)
	if not ExpertSearch.applies(view, config):
		return job.fallback
	return ExpertSearch.run(job, budget)


## What a runner needs to spread one decision over threads.
static func search_job(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig
) -> BotSearchJob:
	var scorer: CandidateScorer = CandidateScorer.new(view.own_counts, table, config.weights)
	var position: BotPosition = BotPosition.new(view, table, config, scorer)
	var play: BotPlay = _by_policy(position, legal)
	var candidates: Array[Pattern] = []
	if ExpertSearch.applies(view, config):
		candidates = legal
	return BotSearchJob.new(position, candidates, play)


static func _by_policy(position: BotPosition, legal: Array[Pattern]) -> BotPlay:
	if position.view.public.current_play == null:
		return LeadPolicy.choose(position, legal)
	return FollowPolicy.choose(position, legal)


## Returns the need the bot declares before a Commons split. A dishonest bot inflates it.
static func declare_need(
	true_need: int, config: BotConfig, stream: RandomStream, _budget: BotBudget
) -> int:
	if stream.next_float() < config.honesty:
		return true_need
	var extra: int = roundi(true_need * BotConfig.TABLE.lie_share)
	return true_need + maxi(extra, BotConfig.TABLE.lie_floor)

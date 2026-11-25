class_name Bot
extends RefCounted
## The only way the game asks a bot for anything. Three pure functions, each with a
## time budget. A bot sees its SeatView and the legal moves, never another hand. A config
## that carries a scripted villager is answered from its script (ADR 0026).


## True claims the landlord seat. counts is the bot's own dealt hand. A bid is decided
## at once, so its budget goes unread; ADR 0009 gives every decision one all the same.
static func decide_bid(
	counts: PackedByteArray,
	is_grab: bool,
	is_last: bool,
	table: BotTable,
	config: BotConfig,
	_budget: BotBudget
) -> bool:
	if config.scripted != null:
		return config.scripted.bid()
	var points: float = BidPolicy.hand_points(counts, table, config.weights)
	return points >= BidPolicy.threshold(is_grab, is_last, config.weights) - config.ambition


## legal is what MoveGenerator lists. Returns a pass only when following.
static func decide_play(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig, budget: BotBudget
) -> BotPlay:
	if config.scripted != null:
		return config.scripted.play(view, legal)
	legal = considered(legal)
	if legal.is_empty():
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.PASS_NOTHING_BEATS)
	if SlackPolicy.slacks(view, config):
		return SlackPolicy.choose(view, legal)
	if config.tier == BotConfig.Tier.EASY:
		return GreedyPolicy.choose(view, legal, table, config)
	var job: BotSearchJob = _job(view, legal, table, config)
	if not config.searches():
		return job.fallback
	return ExpertSearch.run(job, budget)


## What a runner needs to spread one decision over threads.
static func search_job(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig
) -> BotSearchJob:
	legal = considered(legal)
	if SlackPolicy.slacks(view, config):
		var none: Array[Pattern] = []
		return BotSearchJob.new(null, none, SlackPolicy.choose(view, legal))
	return _job(view, legal, table, config)


## The legal moves a bot weighs: every one, less the wild plays it never needs
## (WildSupply.is_lean, ADR 0029). With no wild card in hand that is all of them.
static func considered(legal: Array[Pattern]) -> Array[Pattern]:
	var kept: Array[Pattern] = []
	for move: Pattern in legal:
		if WildSupply.is_lean(move):
			kept.append(move)
	return legal if kept.size() == legal.size() or kept.is_empty() else kept


## The policy's play and the search's candidates, over moves already considered, for a
## bot that is trying.
static func _job(
	view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig
) -> BotSearchJob:
	var scorer: CandidateScorer = CandidateScorer.new(
		view.own_counts, table, config.weights, config.type_bias
	)
	var position: BotPosition = BotPosition.new(view, table, config, scorer)
	var play: BotPlay = _by_policy(position, legal)
	var candidates: Array[Pattern] = []
	if config.searches():
		candidates = legal
	return BotSearchJob.new(position, candidates, play)


static func _by_policy(position: BotPosition, legal: Array[Pattern]) -> BotPlay:
	if position.view.public.current_play == null:
		return LeadPolicy.choose(position, legal)
	return FollowPolicy.choose(position, legal)


## Returns the need the bot declares before a Commons split. A dishonest bot inflates it.
## Decided at once, so its budget goes unread, as a bid's does (ADR 0009).
static func declare_need(
	true_need: int, config: BotConfig, stream: RandomStream, _budget: BotBudget
) -> int:
	if config.scripted != null:
		return config.scripted.need(true_need)
	if stream.next_float() < config.honesty:
		return true_need
	var extra: int = roundi(true_need * config.lie_share)
	return true_need + maxi(extra, BotConfig.TABLE.lie_floor)


## The card IDs the bot hands its teammate when the player calls Mutual Aid on it.
static func choose_gift(view: SeatView, table: BotTable, count: int) -> Array[int]:
	return AidChoice.choose(view, table.rank_map, count)


## A hand split into its fewest plays, for a view that sorts cards by group.
static func suggest_groups(
	counts: PackedByteArray, table: BotTable, config: BotConfig
) -> Array[Pattern]:
	var search: HandDecomposer = HandDecomposer.new(
		table.rules, table.rank_map, config.weights.memo_cap
	)
	return search.decompose(counts).groups

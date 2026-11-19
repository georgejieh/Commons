class_name ExpertPlay
extends RefCounted
## Plays Expert through ExpertRunner, as players get it, against Hard over seeded deals,
## and keeps what each Expert decision took. Shared by tools/expert_deadline.gd and
## tools/perf_budget.gd. Pairs games as in ADR 0010.

const LANDLORD: int = 0

## Expert's actions the round refused.
var illegal: int = 0
## Microseconds each Expert decision took.
var times: PackedInt64Array = PackedInt64Array()
## For each decision that searched: the samples it had, and those finished by the deadline.
var samples: Array[Vector2i] = []

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: SeatRules = SeatRules.uniform(_rules, _map)
var _bot_table: BotTable = BotTable.new(_rules, _map)
var _hard: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD)
var _expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)


## Puts count wild ranks (0 to 2) in force for every seat, drawn from the deal's seed as
## the tournament draws them (ADR 0029).
func use_wild(deal_seed: int, count: int) -> void:
	var params: RuleParams = RuleSet.DEFAULT_PARAMS.copy()
	params.wild_ranks = TournamentRun.wild_ranks_for(deal_seed, count)
	_rules = RuleSet.new(params)
	_table = SeatRules.uniform(_rules, _map)
	_bot_table = BotTable.new(_rules, _map)


## How many of the deal's two games Expert won: once as the landlord, once as the peasants.
func expert_wins(deal: DealResult, limit_usec: int) -> int:
	var wins: int = 0
	if landlord_won(deal, [LANDLORD], limit_usec):
		wins += 1
	if not landlord_won(deal, [1, 2], limit_usec):
		wins += 1
	return wins


## The 99th percentile of the decision times, in microseconds.
func p99_usec() -> int:
	var sorted: PackedInt64Array = times.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return sorted[sorted.size() * 99 / 100]


## How many samples the searched decisions finished by the deadline.
func samples_line() -> String:
	if samples.is_empty():
		return "no decision searched"
	var finished: int = 0
	var whole: int = 0
	var fewest: int = samples[0].y
	for counted: Vector2i in samples:
		finished += counted.y
		whole += 1 if counted.y == counted.x else 0
		fewest = mini(fewest, counted.y)
	return (
		"%d searched decisions: %.1f of %d samples finished on average, all in %d, fewest %d"
		% [samples.size(), float(finished) / samples.size(), samples[0].x, whole, fewest]
	)


func landlord_won(deal: DealResult, expert_seats: Array[int], limit_usec: int) -> bool:
	var round_state: RoundState = RoundState.new(deal, LANDLORD, _table)
	while not round_state.is_over():
		var seat: int = round_state.seat_to_act()
		var legal: Array[Pattern] = round_state.legal_moves()
		var view: SeatView = round_state.view_for(seat)
		var play: BotPlay
		if seat in expert_seats:
			var started: int = Time.get_ticks_usec()
			var runner: ExpertRunner = ExpertRunner.new()
			play = runner.decide(view, legal, _bot_table, _expert, limit_usec)
			times.append(Time.get_ticks_usec() - started)
			if runner.sample_count() > 0:
				samples.append(Vector2i(runner.sample_count(), runner.finished_samples()))
		else:
			play = Bot.decide_play(view, legal, _bot_table, _hard, BotBudget.unlimited())
		var action: RoundAction = RoundAction.new(seat)
		if not play.is_pass():
			action = round_state.action_for(play.pattern)
		if (
			not SelfPlay.is_offered(play, legal)
			or round_state.apply(action) != RoundState.Reason.OK
		):
			illegal += 1
			return false
	return round_state.landlord_won()

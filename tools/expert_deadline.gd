extends SceneTree
## Plays Expert through ExpertRunner, as players get it, against Hard over seeded deals.
## tools/tournament.gd gives Expert unlimited time on one thread, so it can't measure this.
## Pairs games as in ADR 0010. Exits 1 on an illegal action.

const DEFAULT_DEALS: int = 1000
const DEFAULT_LIMIT_USEC: int = 300000
const PROGRESS_DEALS: int = 50
const LANDLORD: int = 0

var _illegal: int = 0
var _times: PackedInt64Array = PackedInt64Array()
var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()
var _table: SeatRules = SeatRules.uniform(_rules, _map)
var _bot_table: BotTable = BotTable.new(_rules, _map)
var _hard: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD)
var _expert: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)


func _initialize() -> void:
	var deals: int = _option("--deals", DEFAULT_DEALS)
	var first_seed: int = _option("--seed", 0)
	var limit: int = _option("--limit-usec", DEFAULT_LIMIT_USEC)
	var wins: int = 0
	for index: int in deals:
		var deal: DealResult = SelfPlay.deal_from_seed(first_seed + index)
		if _landlord_won(deal, [LANDLORD], limit):
			wins += 1
		if not _landlord_won(deal, [1, 2], limit):
			wins += 1
		if (index + 1) % PROGRESS_DEALS == 0:
			print("%d deals, expert %.3f" % [index + 1, float(wins) / ((index + 1) * 2)])
	_times.sort()
	@warning_ignore("integer_division")
	var p99: int = _times[_times.size() * 99 / 100]
	print(
		(
			"expert beats hard %.3f over %d games at %d usec, %d illegal actions, p99 %d usec"
			% [float(wins) / (deals * 2), deals * 2, limit, _illegal, p99]
		)
	)
	quit(1 if _illegal > 0 else 0)


func _landlord_won(deal: DealResult, expert_seats: Array[int], limit: int) -> bool:
	var round_state: RoundState = RoundState.new(deal, LANDLORD, _table)
	while not round_state.is_over():
		var seat: int = round_state.seat_to_act()
		var legal: Array[Pattern] = round_state.legal_moves()
		var view: SeatView = round_state.view_for(seat)
		var play: BotPlay
		if seat in expert_seats:
			var started: int = Time.get_ticks_usec()
			play = ExpertRunner.new().decide(view, legal, _bot_table, _expert, limit)
			_times.append(Time.get_ticks_usec() - started)
		else:
			play = Bot.decide_play(view, legal, _bot_table, _hard, BotBudget.unlimited())
		var action: RoundAction = RoundAction.new(seat)
		if not play.is_pass():
			action = round_state.action_for(play.pattern)
		if (
			not SelfPlay.is_offered(play, legal)
			or round_state.apply(action) != RoundState.Reason.OK
		):
			_illegal += 1
			return false
	return round_state.landlord_won()


func _option(name: String, fallback: int) -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find(name)
	return int(args[at + 1]) if at >= 0 else fallback

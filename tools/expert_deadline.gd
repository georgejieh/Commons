extends SceneTree
## Plays Expert through ExpertRunner, as players get it, against Hard over seeded deals.
## tools/tournament.gd gives Expert unlimited time on one thread, so it can't measure this.
## Pairs games as in ADR 0010. Exits 1 on an illegal action. --wild N puts 0 to 2 wild
## ranks in force for every seat, drawn per deal as the tournament draws them (ADR 0029).
## The play itself is ExpertPlay, which tools/perf_budget.gd shares.

const DEFAULT_DEALS: int = 1000
const PROGRESS_DEALS: int = 50

var _play: ExpertPlay = ExpertPlay.new()


func _initialize() -> void:
	var deals: int = _option("--deals", DEFAULT_DEALS)
	var first_seed: int = _option("--seed", 0)
	# The live game's deadline unless asked otherwise (ADR 0030).
	var limit: int = _option("--limit-usec", BotConfig.DEFAULT_WEIGHTS.expert_deadline_usec)
	var wild: int = _option("--wild", 0)
	var wins: int = 0
	for index: int in deals:
		var deal: DealResult = SelfPlay.deal_from_seed(first_seed + index)
		if wild > 0:
			_play.use_wild(first_seed + index, wild)
		wins += _play.expert_wins(deal, limit)
		if (index + 1) % PROGRESS_DEALS == 0:
			print("%d deals, expert %.3f" % [index + 1, float(wins) / ((index + 1) * 2)])
	print(
		(
			"expert beats hard %.3f over %d games at %d usec, %d wild, %d illegal actions, p99 %d usec"
			% [float(wins) / (deals * 2), deals * 2, limit, wild, _play.illegal, _play.p99_usec()]
		)
	)
	print(_play.samples_line())
	quit(1 if _play.illegal > 0 else 0)


func _option(name: String, fallback: int) -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find(name)
	return int(args[at + 1]) if at >= 0 else fallback

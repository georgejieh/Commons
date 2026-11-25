extends SceneTree
## Plays Expert through ExpertRunner, as players get it, against Hard over seeded deals.
## tools/tournament.gd gives Expert unlimited time on one thread, so it can't measure this.
## Pairs games as in ADR 0010. Exits 1 on an illegal action. --wild N puts 0 to 2 wild
## ranks in force for every seat, drawn per deal as the tournament draws them (ADR 0029).
## The play itself is ExpertPlay, which tools/perf_budget.gd shares.

const USAGE: String = "expert_deadline.gd -- [--deals N] [--seed N] [--limit-usec N] [--wild N]"
const DEFAULT_DEALS: int = 1000
const PROGRESS_DEALS: int = 50

var _play: ExpertPlay = ExpertPlay.new()


func _initialize() -> void:
	var options: ToolOptions = ToolOptions.new(USAGE)
	var deals: int = options.integer("deals", DEFAULT_DEALS, 1)
	var first_seed: int = options.integer("seed", 0)
	# The live game's deadline unless asked otherwise (ADR 0030).
	var deadline: int = BotConfig.DEFAULT_WEIGHTS.expert_deadline_usec
	var limit: int = options.integer("limit-usec", deadline, 1)
	var wild: int = options.integer("wild", 0, 0, TournamentRun.MAX_WILD)
	if options.failed():
		quit(2)
		return
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

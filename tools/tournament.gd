extends SceneTree
## Runs seeded bot games and writes CSV. Exits 1 on any illegal action. Run:
##   godot --headless --path . --script res://tools/tournament.gd -- --games 200 --a medium --b easy
## Options: --seed N, --out PATH, --log PATH, --bidding (also plays games that bid),
## --wild N (0 to 2 ranks wild in every game, drawn per deal) and --big-bombs (five or more
## cards of a rank are a bomb), both for every seat (ADR 0029).

const USAGE: String = (
	"tournament.gd -- --games N --a TIER --b TIER [--seed N] [--out PATH] [--log PATH]"
	+ " [--bidding] [--wild N] [--big-bombs]"
)
const DEFAULT_OUT: String = "reports/tournament.csv"


func _initialize() -> void:
	var options: ToolOptions = ToolOptions.new(USAGE)
	var first: String = options.text("a")
	var second: String = options.text("b")
	if not options.has("games"):
		options.refuse("Needs --games N.")
	var games: int = options.integer("games", 0, 2)
	var wild: int = options.integer("wild", 0, 0, TournamentRun.MAX_WILD)
	var seed_value: int = options.integer("seed", 0)
	if first == second or not _known(first) or not _known(second):
		options.refuse("Needs two different --a and --b from easy, medium, hard, expert.")
	var out: String = options.path("out", DEFAULT_OUT)
	var log_path: String = options.path("log", "") if options.has("log") else ""
	if options.failed():
		quit(2)
		return
	var run: TournamentRun = TournamentRun.new(first, second, seed_value, not log_path.is_empty())
	run.wild = wild
	run.big_bombs = options.has("big-bombs")
	run.play_duplicate(games)
	if options.has("bidding"):
		run.play_bidding(games)
	var saved: bool = ToolFiles.write(out, run.tally.csv())
	if not log_path.is_empty():
		saved = ToolFiles.write(log_path, "\n".join(run.log_lines) + "\n") and saved
	var rate: float = run.tally.win_rate(TournamentRun.DUPLICATE, first)
	var illegal: int = run.tally.illegal_actions
	var rules: String = ""
	if wild > 0 or run.big_bombs:
		rules = " (%d wild, bigger bombs %s)" % [wild, "on" if run.big_bombs else "off"]
	print(
		(
			"%s beats %s %.3f%s, %d illegal actions, CSV at %s"
			% [first, second, rate, rules, illegal, out]
		)
	)
	quit(0 if illegal == 0 and saved else 1)


func _known(name: String) -> bool:
	return TournamentRun.CONFIGS.has(name)

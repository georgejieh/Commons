extends SceneTree
## Runs seeded bot games and writes CSV. Exits 1 on any illegal action. Run:
##   godot --headless --path . --script res://tools/tournament.gd -- --games 200 --a medium --b easy
## Options: --seed N, --out PATH, --log PATH, --bidding (also plays games that bid),
## --wild N (0 to 2 ranks wild in every game, drawn per deal) and --big-bombs (five or more
## cards of a rank are a bomb), both for every seat (ADR 0029).

const DEFAULT_OUT: String = "res://reports/tournament.csv"


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var first: String = options.get("a", "")
	var second: String = options.get("b", "")
	var games: int = int(options.get("games", "0"))
	var wild: int = int(options.get("wild", "0"))
	if games < 2 or first == second or not _known(first) or not _known(second):
		printerr(
			"Needs --games N of at least 2 and two different --a and --b from easy, medium, hard, expert."
		)
		quit(2)
		return
	if wild < 0 or wild > TournamentRun.MAX_WILD:
		printerr("--wild takes 0, 1 or 2.")
		quit(2)
		return
	var log_path: String = options.get("log", "")
	var run: TournamentRun = TournamentRun.new(
		first, second, int(options.get("seed", "0")), not log_path.is_empty()
	)
	run.wild = wild
	run.big_bombs = options.has("big-bombs")
	run.play_duplicate(games)
	if options.has("bidding"):
		run.play_bidding(games)
	var out: String = options.get("out", DEFAULT_OUT)
	var saved: bool = _save(out, run.tally.csv())
	if not log_path.is_empty():
		saved = _save(log_path, "\n".join(run.log_lines) + "\n") and saved
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


func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = 0
	while at < args.size():
		var name: String = args[at].trim_prefix("--")
		var has_value: bool = at + 1 < args.size() and not args[at + 1].begins_with("--")
		options[name] = args[at + 1] if has_value else ""
		at += 2 if has_value else 1
	return options


func _save(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Can't write %s" % path)
		return false
	file.store_string(text)
	return true

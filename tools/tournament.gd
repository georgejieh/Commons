extends SceneTree
## Runs seeded bot games and writes CSV. Exits 1 on any illegal action. Run:
##   godot --headless --path . --script res://tools/tournament.gd -- --games 200 --a medium --b easy
## Options: --seed N, --out PATH, --log PATH, --bidding (also plays games that bid).

const DEFAULT_OUT: String = "res://reports/tournament.csv"


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var first: String = options.get("a", "")
	var second: String = options.get("b", "")
	var games: int = int(options.get("games", "0"))
	if games <= 0 or first == second or not _known(first) or not _known(second):
		printerr("Needs --games N and two different --a and --b from easy, medium, hard, expert.")
		quit(2)
		return
	var log_path: String = options.get("log", "")
	var run: TournamentRun = TournamentRun.new(
		first, second, int(options.get("seed", "0")), not log_path.is_empty()
	)
	run.play_duplicate(games)
	if options.has("bidding"):
		run.play_bidding(games)
	var out: String = options.get("out", DEFAULT_OUT)
	var saved: bool = _save(out, run.tally.csv())
	if not log_path.is_empty():
		saved = _save(log_path, "\n".join(run.log_lines) + "\n") and saved
	var rate: float = run.tally.win_rate(TournamentRun.DUPLICATE, first)
	var illegal: int = run.tally.illegal_actions
	print("%s beats %s %.3f, %d illegal actions, CSV at %s" % [first, second, rate, illegal, out])
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

extends SceneTree
## Measures every row of the performance budget (P5.3) on this machine and writes a report
## to commit. Exits 1 when any measured row misses, 2 on bad options; a row that was not
## measured is never a pass. Run:
##   godot --headless --path . --script res://tools/perf_budget.gd -- --out reports/perf_budget.md
## measures the rows that need no window. The same command without --headless, with
## --windowed-rows, adds startup to the title, frame time during play, nodes made during a
## round and resident memory with the table open.
## Options: --seed N, --hands N (classifier calls), --movegen-hands N, --bot-deals N (per
## Easy, Medium and Hard), --expert-deals N (0 skips Expert), --save-sets N, --save-reps N
## (at least 20 to judge a time), --frame-seconds S, --out PATH. Thresholds are in
## PerfLimits; the rows are built in PerfCore, PerfSaves and PerfWindow.

var _rows: Array[PerfRow] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options: Dictionary[String, String] = _options()
	var first_seed: int = _number(options, "seed", PerfLimits.DEFAULT_SEED)
	var core: PerfCore = PerfCore.new(first_seed)
	var reps: int = _number(options, "save-reps", PerfLimits.DEFAULT_SAVE_REPS)
	if reps < 1:
		printerr("--save-reps takes at least 1.")
		quit(2)
		return
	_add(core.classification(_number(options, "hands", PerfLimits.DEFAULT_HANDS)))
	_add(core.move_generation(_number(options, "movegen-hands", PerfLimits.DEFAULT_MOVEGEN_HANDS)))
	for row: PerfRow in core.bots(_number(options, "bot-deals", PerfLimits.DEFAULT_BOT_DEALS)):
		_add(row)
	var expert_deals: int = _number(options, "expert-deals", PerfLimits.DEFAULT_EXPERT_DEALS)
	if expert_deals > 0:
		_add(core.expert(expert_deals))
	else:
		_add(PerfRow.unmeasured("Bot decision, Expert", "p99 under 400 ms", "--expert-deals 0"))
	var sets: int = _number(options, "save-sets", PerfLimits.DEFAULT_SAVE_SETS)
	for row: PerfRow in PerfSaves.new(first_seed, sets, reps).rows():
		_add(row)
	await _windowed(options, first_seed)
	_finish(options, first_seed, reps)


func _windowed(options: Dictionary[String, String], first_seed: int) -> void:
	var rows: Array[PerfRow]
	if not options.has("windowed-rows"):
		rows = PerfWindow.unmeasured("run without --headless and with --windowed-rows")
	elif not PerfWindow.has_window():
		rows = PerfWindow.unmeasured(PerfWindow.NO_WINDOW)
	else:
		var seconds: float = float(
			options.get("frame-seconds", str(PerfLimits.DEFAULT_FRAME_SECONDS))
		)
		rows = await PerfWindow.new(self, first_seed, seconds).measure()
	for row: PerfRow in rows:
		_add(row)


func _add(row: PerfRow) -> void:
	_rows.append(row)
	print(row.line())


func _finish(options: Dictionary[String, String], first_seed: int, reps: int) -> void:
	var out: String = options.get("out", PerfLimits.DEFAULT_OUT)
	var run_line: String = (
		"seed %d, %d save repetitions, %s"
		% [
			first_seed,
			reps,
			"windowed rows asked for" if options.has("windowed-rows") else "headless rows"
		]
	)
	var text: String = PerfReport.markdown(_rows, PerfReport.machine_facts(), run_line)
	var saved: bool = _save(out, text)
	print(PerfReport.summary(_rows))
	print("Report at %s" % out)
	quit(0 if PerfReport.missed(_rows) == 0 and saved else 1)


func _number(options: Dictionary[String, String], name: String, fallback: int) -> int:
	return int(options.get(name, str(fallback)))


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

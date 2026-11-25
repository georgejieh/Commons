extends SceneTree
## Measures every row of the performance budget on this machine and writes a report to
## commit. Exits 1 when any measured row misses or the report cannot be written, 2 on bad
## options; a row that was not measured is never a pass. Run:
##   godot --headless --path . --script res://tools/perf_budget.gd -- --out reports/perf_budget.md
## measures the rows that need no window. The same command without --headless, with
## --windowed-rows, adds startup to the title, frame time during play, nodes made during a
## round and resident memory with the table open.
## Options: --seed N, --hands N (classifier calls), --movegen-hands N, --bot-deals N (per
## Easy, Medium and Hard), --expert-deals N (0 skips Expert), --save-sets N, --save-reps N
## (fewer than PerfLimits.MIN_SAVE_REPS, and the save and load times are not judged),
## --frame-seconds S, --profile NAME (a sandbox folder of its own), --out PATH. Thresholds
## are in PerfLimits; the rows are built in PerfCore, PerfSaves and PerfWindow.

const USAGE: String = (
	"perf_budget.gd -- [--seed N] [--hands N] [--movegen-hands N] [--bot-deals N]"
	+ " [--expert-deals N] [--save-sets N] [--save-reps N] [--frame-seconds S]"
	+ " [--windowed-rows] [--profile NAME] [--out PATH]"
)

var _rows: Array[PerfRow] = []
var _options: ToolOptions


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_options = ToolOptions.new(USAGE)
	var first_seed: int = _options.integer("seed", PerfLimits.DEFAULT_SEED)
	var hands: int = _options.integer("hands", PerfLimits.DEFAULT_HANDS, 1)
	var movegen_hands: int = _options.integer("movegen-hands", PerfLimits.DEFAULT_MOVEGEN_HANDS, 1)
	var bot_deals: int = _options.integer("bot-deals", PerfLimits.DEFAULT_BOT_DEALS, 1)
	var expert_deals: int = _options.integer("expert-deals", PerfLimits.DEFAULT_EXPERT_DEALS, 0)
	var sets: int = _options.integer("save-sets", PerfLimits.DEFAULT_SAVE_SETS, 1)
	var reps: int = _options.integer("save-reps", PerfLimits.DEFAULT_SAVE_REPS, 1)
	var seconds: float = _options.number("frame-seconds", PerfLimits.DEFAULT_FRAME_SECONDS, 1.0)
	var out: String = _options.path("out", PerfLimits.DEFAULT_OUT)
	if _options.failed():
		quit(2)
		return
	var core: PerfCore = PerfCore.new(first_seed)
	_add(core.classification(hands))
	_add(core.move_generation(movegen_hands))
	for row: PerfRow in core.bots(bot_deals):
		_add(row)
	if expert_deals > 0:
		_add(core.expert(expert_deals))
	else:
		_add(
			PerfRow.unmeasured(
				"Bot decision, Expert", PerfLimits.expert_budget(), "--expert-deals 0"
			)
		)
	var folder: String = WalkProfile.folder(PerfLimits.SAVE_BASE, _options)
	for row: PerfRow in PerfSaves.new(first_seed, sets, reps, folder).rows():
		_add(row)
	await _windowed(first_seed, seconds)
	_finish(out, first_seed, reps)


func _windowed(first_seed: int, seconds: float) -> void:
	var rows: Array[PerfRow]
	if not _options.has("windowed-rows"):
		rows = PerfWindow.unmeasured("run without --headless and with --windowed-rows")
	elif not PerfWindow.has_window():
		rows = PerfWindow.unmeasured(PerfWindow.NO_WINDOW)
	else:
		rows = await PerfWindow.new(self, first_seed, seconds, _options).measure()
	for row: PerfRow in rows:
		_add(row)


func _add(row: PerfRow) -> void:
	_rows.append(row)
	print(row.line())


func _finish(out: String, first_seed: int, reps: int) -> void:
	var asked: String = (
		"windowed rows asked for" if _options.has("windowed-rows") else "headless rows"
	)
	var run_line: String = "seed %d, %d save repetitions, %s" % [first_seed, reps, asked]
	var text: String = PerfReport.markdown(_rows, PerfReport.machine_facts(), run_line)
	var saved: bool = ToolFiles.write(out, text)
	print(PerfReport.summary(_rows))
	print("Report at %s" % out)
	quit(0 if PerfReport.missed(_rows) == 0 and saved else 1)

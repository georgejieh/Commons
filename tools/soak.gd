extends SceneTree
## The soak (ADR 0037): plays full runs headless, each saved through the real SaveService
## as it plays and resumed from its save at every Set's end (SoakDriver), with the
## collective, private and mixed strategies taken in turn and the stakes in turn under
## each, every unlock tier open. Writes reports/soak.md with the count of each kind of
## fault and the seeds of any run that failed, and exits 1 on any fault. Run:
##   godot --headless --path . --script res://tools/soak.gd -- --runs 100
## Options: --runs N (100 unless set), --seed S the first seed, --jobs J worker threads,
## --expert-samples N the deals an Expert villager samples (the game's own unless set;
## never fewer than a search decides on), --out DIR. Exits 2 on bad options.

const DEFAULT_RUNS: int = 100
const DEFAULT_OUT: String = "res://reports"
## Where each run keeps its save while it plays: a folder by seed. A failed run's save is
## left there to be read.
const SAVE_ROOT: String = "user://soak"

var _runs: int = DEFAULT_RUNS
var _first_seed: int = 0
var _expert_samples: int = 0
var _log: SoakLog = SoakLog.new()
var _totals: SoakFaults = SoakFaults.new()
var _failed: Array[BalanceResult] = []
var _mutex: Mutex = Mutex.new()
var _next: int = 0
var _done: int = 0


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var problem: String = _read(options)
	if not problem.is_empty():
		printerr(problem)
		quit(2)
		return
	var jobs: int = maxi(int(options.get("jobs", "1")), 1)
	var began: int = Time.get_ticks_msec()
	# Worked out once here: every save is stamped with it, from every worker.
	ContentStamp.current()
	OS.add_logger(_log)
	_play_all(jobs)
	OS.remove_logger(_log)
	var seconds: float = (Time.get_ticks_msec() - began) / 1000.0
	var out: String = options.get("out", DEFAULT_OUT)
	var saved: bool = _save(out.path_join("soak.md"), _report(seconds, jobs))
	for result: BalanceResult in _failed:
		printerr("Failed: seed %d, %s: %s" % [result.seed_value, result.strategy, result.failure])
	print("%d runs, %d failed, %d faults." % [_done, _failed.size(), _totals.total()])
	quit(0 if saved and _totals.total() == 0 and _failed.is_empty() else 1)


## The strategy and stake of the run at index, in turn.
static func plan(index: int) -> Vector2i:
	var strategies: int = BalanceDriver.STRATEGIES.size()
	var stakes: int = RunStakes.last() + 1
	@warning_ignore("integer_division")
	return Vector2i(index % strategies, (index / strategies) % stakes)


## The report: what was played, each count, and each failed run's seed and reason.
static func markdown(
	totals: SoakFaults, failed: Array[BalanceResult], runs: int, setup: Dictionary
) -> String:
	var lines: PackedStringArray = ["# Soak", ""]
	lines.append(
		(
			"%d full runs from seed %d, saved and resumed at every Set's end. %s."
			% [runs, setup.get("first_seed", 0), setup.get("note", "")]
		)
	)
	lines.append_array(["", "| Fault | Count |", "| --- | --- |"])
	var counts: Array[int] = totals.counts()
	for at: int in SoakFaults.NAMES.size():
		lines.append("| %s | %d |" % [SoakFaults.NAMES[at], counts[at]])
	lines.append("")
	if failed.is_empty():
		lines.append("No run failed.")
	else:
		lines.append("Failed runs:")
		lines.append("")
		for result: BalanceResult in failed:
			lines.append(
				(
					"- seed %d, %s, stake %d: %s"
					% [result.seed_value, result.strategy, result.stake, result.failure]
				)
			)
	return "\n".join(lines) + "\n"


func _report(seconds: float, jobs: int) -> String:
	var samples: String = (
		"Expert villagers sampled %d deals" % _expert_samples
		if _expert_samples > 0
		else "Expert villagers sampled the game's own number of deals"
	)
	var note: String = "%s; %d jobs; %.0f seconds" % [samples, jobs, seconds]
	return markdown(_totals, _failed, _done, {"first_seed": _first_seed, "note": note})


## Reads the options. Returns what is wrong with them, or "".
func _read(options: Dictionary[String, String]) -> String:
	_runs = int(options.get("runs", str(DEFAULT_RUNS)))
	_first_seed = int(options.get("seed", "0"))
	_expert_samples = int(options.get("expert-samples", "0"))
	if _runs < 1:
		return "Needs --runs N of at least 1."
	var fewest: int = BotConfig.DEFAULT_WEIGHTS.expert_min_samples
	if options.has("expert-samples") and _expert_samples < fewest:
		return "Needs --expert-samples of at least %d, the fewest a search decides on." % fewest
	return ""


func _play_all(jobs: int) -> void:
	if jobs == 1:
		_work()
		return
	var threads: Array[Thread] = []
	for job: int in jobs:
		var thread: Thread = Thread.new()
		thread.start(_work)
		threads.append(thread)
	for thread: Thread in threads:
		thread.wait_to_finish()


## Takes runs until none are left. Each driver is made under the lock: duplicating a
## Resource on many threads at once is not known to be safe.
func _work() -> void:
	while true:
		_mutex.lock()
		if _next >= _runs:
			_mutex.unlock()
			return
		var index: int = _next
		_next += 1
		var turn: Vector2i = plan(index)
		var seed_value: int = _first_seed + index
		var strategy: BalanceStrategy = BalanceDriver.strategy_named(
			BalanceDriver.STRATEGIES[turn.x]
		)
		var folder: String = SAVE_ROOT.path_join(str(seed_value))
		var driver: SoakDriver = SoakDriver.new(strategy, turn.y, _log, folder)
		if _expert_samples > 0:
			driver.search_weights = BalanceDriver.sampling(_expert_samples)
		_mutex.unlock()
		var result: BalanceResult = driver.play(seed_value)
		_mutex.lock()
		_done += 1
		_totals.add(driver.faults)
		if result.failed():
			_failed.append(result)
		print(_progress(result, driver.faults))
		_mutex.unlock()


func _progress(result: BalanceResult, faults: SoakFaults) -> String:
	var shown: String = "FAILED " + result.failure if result.failed() else result.outcome
	return (
		"%d/%d seed %d %s stake %d: %s Y%d, %d faults, %.0fs"
		% [
			_done,
			_runs,
			result.seed_value,
			result.strategy,
			result.stake,
			shown,
			result.year,
			faults.total(),
			result.seconds,
		]
	)


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
	return file.store_string(text)

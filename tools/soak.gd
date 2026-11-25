extends SceneTree
## The soak (ADR 0037): plays full runs headless, each saved through the real SaveService
## as it plays and resumed from its save at every Set's end (SoakDriver), with the
## collective, private and mixed strategies taken in turn and the stakes in turn under
## each, every unlock tier open. Writes reports/soak.md with the count of each kind of
## fault and the seeds of any run that failed, and exits 1 on any fault. Run:
##   godot --headless --path . --script res://tools/soak.gd -- --runs 100
## Options: --runs N (100 unless set), --seed S the first seed, --jobs J worker threads,
## --expert-samples N the deals an Expert villager samples (the game's own unless set;
## never fewer than a search decides on), --out DIR. Exits 2 on bad options. Each run
## keeps its save while it plays in a folder by seed under the tool's own folder in the
## sandbox (WalkProfile), user://tools/soak/; a failed run's save is left there to be read.

const USAGE: String = "soak.gd -- [--runs N] [--seed S] [--jobs J] [--expert-samples N] [--out DIR]"
const DEFAULT_RUNS: int = 100
const DEFAULT_OUT: String = "reports"
const SAVE_BASE: String = "soak"

var _runs: int = DEFAULT_RUNS
var _first_seed: int = 0
var _expert_samples: int = 0
var _log: SoakLog = SoakLog.new()
var _totals: SoakFaults = SoakFaults.new()
var _failed: Array[BalanceResult] = []
var _mutex: Mutex = Mutex.new()
var _next: int = 0
var _done: int = 0
var _save_root: String


func _initialize() -> void:
	var options: ToolOptions = ToolOptions.new(USAGE)
	_runs = options.integer("runs", DEFAULT_RUNS, 1)
	_first_seed = options.integer("seed", 0)
	# Never fewer than a search decides on (ADR 0030); 0 keeps the game's own number.
	_expert_samples = options.integer(
		"expert-samples", 0, BotConfig.DEFAULT_WEIGHTS.expert_min_samples
	)
	var jobs: int = options.integer("jobs", 1, 1)
	var out: String = options.path("out", DEFAULT_OUT)
	if options.failed():
		quit(2)
		return
	_save_root = WalkProfile.folder(SAVE_BASE, options)
	var began: int = Time.get_ticks_msec()
	# Worked out once here: every save is stamped with it, from every worker.
	ContentStamp.current()
	OS.add_logger(_log)
	WorkerPool.run(_work, jobs)
	OS.remove_logger(_log)
	var seconds: float = (Time.get_ticks_msec() - began) / 1000.0
	var saved: bool = ToolFiles.write(out.path_join("soak.md"), _report(seconds, jobs))
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


## The report: what was played from first_seed, with note on how, each count, and each
## failed run's seed and reason.
static func markdown(
	totals: SoakFaults, failed: Array[BalanceResult], runs: int, first_seed: int, note: String
) -> String:
	var lines: PackedStringArray = ["# Soak", ""]
	lines.append(
		(
			"%d full runs from seed %d, saved and resumed at every Set's end. %s."
			% [runs, first_seed, note]
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
	return markdown(_totals, _failed, _done, _first_seed, note)


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
		var folder: String = _save_root.path_join(str(seed_value))
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

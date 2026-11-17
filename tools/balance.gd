extends SceneTree
## The balance harness (ADR 0027): plays full runs headless with each strategy on the same
## seeds and writes reports/balance_runs.csv, reports/balance_quotas.csv (a row per
## Quota) and reports/balance.md. Run:
##   godot --headless --path . --script res://tools/balance.gd -- --runs 20
## Options: --runs N seeds a strategy, --seed S the first, --strategies a,b,c, --minutes M
## a time budget, --out DIR, --stake K, --jobs J worker threads, --expert-samples N the
## deals an Expert villager samples (never fewer than a search decides on, ADR 0030),
## --check (exit 1 when the ordering does not hold). Exits 1 on any failed run, 2 on bad
## options.

const DEFAULT_OUT: String = "res://reports"
## Seeds a strategy when neither --runs nor --minutes limits them.
const DEFAULT_RUNS: int = 20

var _first_seed: int = 0
var _seeds: int = 0
var _deadline_msec: int = 0
var _strategies: Array[String] = []
var _stake: int = 0
## The deals an Expert villager samples, or 0 for the game's own number.
var _expert_samples: int = 0
var _errors: BalanceErrors = BalanceErrors.new()
var _mutex: Mutex = Mutex.new()
var _next: int = 0
var _finished: int = 0
## Runs waiting for a worker, as seed and strategy index.
var _queue: Array[Vector2i] = []
## The runs played so far of each seed not yet finished by every strategy.
var _played: Dictionary[int, Array] = {}
var _tally: BalanceTally


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var problem: String = _read(options)
	if not problem.is_empty():
		printerr(problem)
		quit(2)
		return
	var minutes: float = float(options.get("minutes", "0"))
	var jobs: int = maxi(int(options.get("jobs", "1")), 1)
	var began: int = Time.get_ticks_msec()
	_deadline_msec = began + int(minutes * 60_000.0) if minutes > 0.0 else 0
	_tally = BalanceTally.new(_strategies)
	OS.add_logger(_errors)
	_play_all(jobs)
	OS.remove_logger(_errors)
	var setup: Dictionary = {
		"seeds": _finished,
		"first_seed": _first_seed,
		"stake": _stake,
		"minutes": minutes,
		"jobs": jobs,
		"wall_seconds": (Time.get_ticks_msec() - began) / 1000.0,
		"expert_samples": _expert_samples,
	}
	print(_wild_line())
	print(_wave_line())
	var out: String = options.get("out", DEFAULT_OUT)
	var saved: bool = _save(out.path_join("balance_runs.csv"), _tally.csv())
	saved = _save(out.path_join("balance_quotas.csv"), _tally.quotas_csv()) and saved
	saved = _save(out.path_join("balance.md"), BalanceReport.markdown(_tally, setup)) and saved
	quit(_exit_code(saved, options.has("check")))


## How often each of the wild ranks' items was bought, and the runs that played a rank
## wild (ADR 0029).
func _wild_line() -> String:
	var bought: Dictionary[String, int] = {}
	var runs: int = 0
	var draws: int = 0
	var used: int = 0
	for result: BalanceResult in _tally.runs():
		for item_id: String in result.wild_buys:
			bought[item_id] = bought.get(item_id, 0) + result.wild_buys[item_id]
		runs += 1 if result.wild_draws > 0 else 0
		draws += result.wild_draws
		used += result.workers_used
	var parts: PackedStringArray = []
	for item_id: String in BalanceDriver.WILD_ITEMS:
		parts.append("%s %d" % [item_id, bought.get(item_id, 0)])
	var bought_line: String = (
		"wild items bought: %s; Model Workers used: %d" % [", ".join(parts), used]
	)
	return bought_line + "; runs with a wild rank: %d, ranks drawn: %d" % [runs, draws]


## How often each of ADR 0032's pieces was bought, each of its Campaigns used, and the
## runs that reached The Commons, by strategy.
func _wave_line() -> String:
	var bought: Dictionary[String, int] = {}
	var used: Dictionary[String, int] = {}
	var commons: Dictionary[String, int] = {}
	for result: BalanceResult in _tally.runs():
		for item_id: String in result.wave_buys:
			bought[item_id] = bought.get(item_id, 0) + result.wave_buys[item_id]
		for item_id: String in result.wave_uses:
			used[item_id] = used.get(item_id, 0) + result.wave_uses[item_id]
		if result.outcome == Endings.THE_COMMONS:
			commons[result.strategy] = commons.get(result.strategy, 0) + 1
	var parts: PackedStringArray = []
	for item_id: String in BalanceWave.ITEMS:
		parts.append("%s %d/%d" % [item_id, bought.get(item_id, 0), used.get(item_id, 0)])
	var reached: PackedStringArray = []
	for strategy: String in _strategies:
		reached.append("%s %d" % [strategy, commons.get(strategy, 0)])
	return (
		"second wave bought/used: %s; runs reaching the_commons: %s"
		% [", ".join(parts), ", ".join(reached)]
	)


## Reads the options into the run's fields. Returns what is wrong with them, or "".
func _read(options: Dictionary[String, String]) -> String:
	_first_seed = int(options.get("seed", "0"))
	_stake = int(options.get("stake", "0"))
	var limit: int = DEFAULT_RUNS if not options.has("minutes") else 1 << 30
	_seeds = int(options.get("runs", str(limit)))
	var names: String = options.get("strategies", ",".join(BalanceDriver.STRATEGIES))
	for strategy: String in names.split(",", false):
		if BalanceDriver.strategy_named(strategy) == null or _strategies.has(strategy):
			return "Unknown or repeated strategy %s: use collective, private, mixed." % strategy
		_strategies.append(strategy)
	if _strategies.is_empty() or _seeds < 1:
		return "Needs --runs N of at least 1 and at least one strategy."
	if _stake < 0 or _stake > RunStakes.last():
		return "Needs --stake from 0 to %d." % RunStakes.last()
	_expert_samples = int(options.get("expert-samples", "0"))
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


## Takes runs until the seeds or the time run out. A seed is taken only while time is
## left, and every strategy's run of it is queued at once, so each one taken is played
## by every strategy, which keeps the seeds the same for all; workers share its runs, so
## a seed taken late runs over the budget by about one run, not by all of them.
func _work() -> void:
	while true:
		_mutex.lock()
		if _queue.is_empty() and not _take_seed():
			_mutex.unlock()
			return
		var task: Vector2i = _queue.pop_front()
		var driver: BalanceDriver = BalanceDriver.new(
			BalanceDriver.strategy_named(_strategies[task.y]), _stake, _errors
		)
		# Each run gets its own copy, made under the lock: duplicating a Resource on many
		# threads at once is not known to be safe.
		if _expert_samples > 0:
			driver.search_weights = BalanceDriver.sampling(_expert_samples)
		_mutex.unlock()
		var result: BalanceResult = driver.play(task.x)
		_mutex.lock()
		_tally.add(result)
		var played: Array = _played.get(task.x, [])
		played.append(result)
		_played[task.x] = played
		if played.size() == _strategies.size():
			_finished += 1
			_played.erase(task.x)
			print(_progress(task.x, played))
		_mutex.unlock()


## Queues every strategy's run of the next seed, while seeds and time are left. The
## caller holds the mutex.
func _take_seed() -> bool:
	var out_of_time: bool = _deadline_msec > 0 and Time.get_ticks_msec() >= _deadline_msec
	if _next >= _seeds or out_of_time:
		return false
	for strategy: int in _strategies.size():
		_queue.append(Vector2i(_first_seed + _next, strategy))
	_next += 1
	return true


func _progress(seed_value: int, played: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for result: BalanceResult in played:
		var shown: String = "FAILED " + result.failure if result.failed() else result.outcome
		parts.append("%s %s Y%d %.0fs" % [result.strategy, shown, result.year, result.seconds])
	return "%d seeds, seed %d: %s" % [_finished, seed_value, ", ".join(parts)]


func _exit_code(saved: bool, check: bool) -> int:
	var failed: Array[BalanceResult] = _tally.failures()
	for result: BalanceResult in failed:
		printerr("Failed: seed %d, %s: %s" % [result.seed_value, result.strategy, result.failure])
	var verdict: BalanceVerdict = _tally.verdict()
	print("%d seeds a strategy finished. %s" % [_finished, verdict.line()])
	if not saved or not failed.is_empty():
		return 1
	return 1 if check and not verdict.passed else 0


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

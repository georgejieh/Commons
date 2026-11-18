class_name ExpertRunner
extends RefCounted
## Runs one Expert decision on the worker pool and enforces its deadline. Core stays free
## of threads and clocks (ADR 0009). At the deadline it decides on the samples finished:
## no sample starts after it, and one already running has the grace in the weights to
## finish before it is abandoned. decide() waits for
## the decision on the calling thread; start() returns at once, and is_finished() moves
## the decision on each time it is asked, so the game can poll it once a frame (P5.0).

enum Stage { IDLE, BUILDING, SEARCHING, DONE }

const WAIT_STEP_MSEC: int = 1

var _job: BotSearchJob
## Read by every worker, written only on the thread that runs the runner. Samples not yet
## started are skipped, and one already running finishes first.
var _expired: bool = false
## When no sample may start any more, in Time.get_ticks_usec(). Workers read it.
var _deadline: int = 0
## Expires a grace after the deadline. Workers read it between a rollout's steps.
var _stop: BotBudget = BotBudget.unlimited()
var _stage: Stage = Stage.IDLE
var _task: int = -1
var _group: int = -1
var _play: BotPlay = null


func decide(
	view: SeatView,
	legal: Array[Pattern],
	table: BotTable,
	config: BotConfig,
	limit_usec: int,
) -> BotPlay:
	var deadline: int = Time.get_ticks_usec() + limit_usec
	_deadline = deadline
	_expired = false
	_stop = _stop_after(limit_usec, config)
	_job = Bot.search_job(view, legal, table, config)
	if not _job.is_ready() or Time.get_ticks_usec() >= deadline:
		return _job.fallback
	var group: int = WorkerThreadPool.add_group_task(_run_sample, _job.sample_count(), _threads())
	while not WorkerThreadPool.is_group_task_completed(group):
		if Time.get_ticks_usec() >= deadline:
			_expired = true
		OS.delay_msec(WAIT_STEP_MSEC)
	WorkerThreadPool.wait_for_group_task_completion(group)
	return _job.best()


## The live game's searcher (ADR 0030): decides under the deadline in the config's weights.
func search(view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig) -> BotPlay:
	return decide(view, legal, table, config, config.weights.expert_deadline_usec)


## Starts a decision as decide() makes it, and returns at once. Even the policy's play,
## which the search starts from, is worked out on the pool. The inputs must not change
## until the decision is finished.
func start(
	view: SeatView,
	legal: Array[Pattern],
	table: BotTable,
	config: BotConfig,
	limit_usec: int,
) -> void:
	assert(_stage == Stage.IDLE or _stage == Stage.DONE, "A runner decides one play at a time")
	_deadline = Time.get_ticks_usec() + limit_usec
	_expired = false
	_stop = _stop_after(limit_usec, config)
	_play = null
	_job = null
	_task = WorkerThreadPool.add_task(_build.bind(view, legal, table, config))
	_stage = Stage.BUILDING


## True once the decision start() began is made. Never waits: each call takes it as far
## as the pool has, and starts the samples once the policy's play is worked out.
func is_finished() -> bool:
	if _stage == Stage.BUILDING:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		if not _job.is_ready() or _past_deadline():
			_done(_job.fallback)
			return true
		_group = WorkerThreadPool.add_group_task(_run_sample, _job.sample_count(), _threads())
		_stage = Stage.SEARCHING
	if _stage == Stage.SEARCHING:
		if not WorkerThreadPool.is_group_task_completed(_group):
			return false
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_done(_job.best())
	return _stage == Stage.DONE


## The play start() decided, once is_finished() is true; null before.
func play() -> BotPlay:
	return _play


## Lets no further sample start, for a decision nobody will take. One running finishes.
func stop() -> void:
	_expired = true


## Waits on this thread until the decision start() began is made.
func finish() -> void:
	while _stage != Stage.IDLE and not is_finished():
		OS.delay_msec(WAIT_STEP_MSEC)


## The samples the last decision had to run, none when it had no choice to search.
func sample_count() -> int:
	return _job.sample_count()


func finished_samples() -> int:
	return _job.finished_samples()


func _build(view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig) -> void:
	_job = Bot.search_job(view, legal, table, config)


func _done(decided: BotPlay) -> void:
	_play = decided
	_stage = Stage.DONE


## The pool threads the samples are spread over: all but one, which is left to the thread
## that draws the table while a villager thinks (P5.0). decide() keeps to the same count,
## so a tool that measures it measures what the game plays with.
static func _threads() -> int:
	return maxi(1, OS.get_processor_count() - 1)


## The budget that ends a running sample: the deadline and the weights' grace.
static func _stop_after(limit_usec: int, config: BotConfig) -> BotBudget:
	return BotBudget.new(limit_usec + config.weights.expert_grace_usec, Time.get_ticks_usec)


func _past_deadline() -> bool:
	return _expired or Time.get_ticks_usec() >= _deadline


func _run_sample(sample: int) -> void:
	if not _past_deadline():
		_job.run_sample(sample, _stop)

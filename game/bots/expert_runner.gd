class_name ExpertRunner
extends RefCounted
## Runs one Expert decision on the worker pool and enforces its deadline. Core stays free
## of threads and clocks (ADR 0009). If the deadline passes, the Hard decision stands.

const WAIT_STEP_MSEC: int = 1

var _job: BotSearchJob
## Read by every worker, written only here. Samples not yet started are skipped, and one
## already running finishes first.
var _expired: bool = false


func decide(
	view: SeatView,
	legal: Array[Pattern],
	table: BotTable,
	config: BotConfig,
	limit_usec: int,
) -> BotPlay:
	var deadline: int = Time.get_ticks_usec() + limit_usec
	_expired = false
	_job = Bot.search_job(view, legal, table, config)
	if not _job.is_ready():
		return _job.fallback
	var group: int = WorkerThreadPool.add_group_task(_run_sample, _job.sample_count())
	while not WorkerThreadPool.is_group_task_completed(group):
		if Time.get_ticks_usec() >= deadline:
			_expired = true
		OS.delay_msec(WAIT_STEP_MSEC)
	WorkerThreadPool.wait_for_group_task_completion(group)
	_expired = _expired or Time.get_ticks_usec() >= deadline
	return _job.fallback if _expired else _job.best()


func _run_sample(sample: int) -> void:
	if not _expired:
		_job.run_sample(sample)

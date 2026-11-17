class_name VillagerSearches
extends RefCounted
## The searches a controller runs on the worker pool for villagers its loop stands still
## for (P5.0). One at most belongs to the loop's request now. A search let go of while it
## runs, because the run was replaced, dropped or left the tree, is kept until its samples
## finish and is then thrown away, so no worker is left calling into a runner that is gone
## and no play reaches a loop that no longer waits for it.

var _runner: ExpertRunner = null
var _loop: RunLoop = null
var _request: SearchRequest = null
var _stale: Array[ExpertRunner] = []


## Starts the search for the villager the loop stands still for, unless one already runs
## for that very request.
func serve(loop: RunLoop) -> void:
	if _fits(loop):
		return
	let_go()
	_loop = loop
	_request = loop.search_request()
	_runner = ExpertRunner.new()
	var config: BotConfig = _request.config
	var limit: int = config.weights.expert_deadline_usec
	_runner.start(_request.view, _request.legal, _request.table, config, limit)


## The play for the request the loop stands still for, once its search is finished, and
## null until then. A finished search the loop no longer waits for is thrown away. Never
## waits.
func poll(loop: RunLoop) -> BotPlay:
	_drop_finished()
	if _runner == null or not _runner.is_finished():
		return null
	var fits: bool = _fits(loop)
	var play: BotPlay = _runner.play()
	_clear()
	return play if fits else null


## Waits on this thread for the search of the request the loop stands still for, and
## returns its play; null when none runs for it.
func wait(loop: RunLoop) -> BotPlay:
	if not _fits(loop):
		return null
	_runner.finish()
	return poll(loop)


## Stops the search running now, if any, from starting more samples, and keeps it until
## it finishes. Its play is never taken.
func let_go() -> void:
	if _runner != null:
		_runner.stop()
		_stale.append(_runner)
	_clear()


## Lets every search go and waits for each to finish, as when the controller leaves the
## tree and nothing will poll them.
func wait_all() -> void:
	let_go()
	for runner: ExpertRunner in _stale:
		runner.finish()
	_stale.clear()


## Searches started and not yet finished and thrown away, the current one included.
func running() -> int:
	return _stale.size() + (0 if _runner == null else 1)


func _fits(loop: RunLoop) -> bool:
	return (
		_runner != null
		and loop != null
		and loop == _loop
		and loop.awaiting() == RunLoop.Awaiting.VILLAGER_SEARCH
		and loop.search_request() == _request
	)


func _drop_finished() -> void:
	var kept: Array[ExpertRunner] = []
	for runner: ExpertRunner in _stale:
		if not runner.is_finished():
			kept.append(runner)
	_stale = kept


func _clear() -> void:
	_runner = null
	_loop = null
	_request = null

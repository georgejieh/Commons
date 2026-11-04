class_name EventPlayer
extends Node
## Plays the run's events one at a time, a step apart, so each bot play can be seen.
## One command can produce a whole trick of events; the queue spaces them out. Views
## connect to played and read the run only once the queue is empty.

signal played(event: RunEvent)
signal drained

## Seconds between events.
var step: float = 0.55
## Holds the queue still during a hit-stop.
var motion: TableMotion = null

var _queue: Array[RunEvent] = []
var _wait: float = 0.0


func push(event: RunEvent) -> void:
	_queue.append(event)


func is_idle() -> bool:
	return _queue.is_empty()


## Plays every queued event now, for tests and skipping.
func flush() -> void:
	while not _queue.is_empty():
		played.emit(_queue.pop_front())
	drained.emit()


func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	if motion != null and motion.is_stopped():
		return
	_wait -= delta
	while _wait <= 0.0 and not _queue.is_empty():
		var event: RunEvent = _queue.pop_front()
		played.emit(event)
		if _shows(event):
			_wait = step
	if _queue.is_empty():
		drained.emit()


## Only bids, plays, passes and trick ends take a step; bookkeeping goes at once.
func _shows(event: RunEvent) -> bool:
	if event.type != RunEvent.Type.ROUND:
		return event.type in [RunEvent.Type.BID, RunEvent.Type.LANDLORD_CHOSEN]
	return (
		event.round_event.type
		in [RoundEvent.Type.PLAYED, RoundEvent.Type.PASSED, RoundEvent.Type.TRICK_WON]
	)

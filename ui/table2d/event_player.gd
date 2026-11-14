class_name EventPlayer
extends Node
## Plays the run's events one at a time, a step apart, so each bot play can be seen.
## One command can produce a whole trick of events; the queue spaces them out. Views
## connect to played and read the run only once the queue is empty.

signal played(event: RunEvent)
signal queued
signal drained

## Seconds between events, and the pause after a round ends so its banner can be read.
var step: float = 0.55
var round_end_hold: float = 1.6
## Seconds to wait after an event of a run type, where that differs from a step.
var holds: Dictionary[int, float] = {}
## Seconds after a play before its score is counted, or negative to use a full step.
var play_wait: float = -1.0
## True while flush() plays the queue at once: nothing should be acted out.
var flushing: bool = false
## Holds the queue still during a hit-stop.
var motion: TableMotion = null

var _queue: Array[RunEvent] = []
var _wait: float = 0.0
## True when the last event asked for a hold: drained then waits for it to pass.
var _held: bool = false
var _draining: bool = false


func push(event: RunEvent) -> void:
	_queue.append(event)
	queued.emit()


## True when nothing is queued and no moment is still playing out.
func is_idle() -> bool:
	return _queue.is_empty() and not _draining


## Plays every queued event now, for tests and skipping.
func flush() -> void:
	flushing = true
	while not _queue.is_empty():
		played.emit(_queue.pop_front())
	flushing = false
	_wait = 0.0
	_held = false
	_draining = false
	drained.emit()


## Keeps the queue still for at least this long from now, while a moment plays out.
func hold(seconds: float) -> void:
	_wait = maxf(_wait, seconds)
	_held = true


func _process(delta: float) -> void:
	if _queue.is_empty() and not _draining:
		return
	if motion != null and motion.is_stopped():
		return
	_wait -= delta
	while _wait <= 0.0 and not _queue.is_empty():
		var event: RunEvent = _queue.pop_front()
		# A handler may hold the queue, so every wait below only ever lengthens it.
		_wait = 0.0
		_held = false
		played.emit(event)
		if _shows(event):
			_wait = maxf(_wait, _step_for(event))
		if holds.has(event.type):
			_wait = maxf(_wait, holds[event.type])
		if _ends_round(event):
			_wait = maxf(_wait, round_end_hold)
	if not _queue.is_empty():
		return
	# A moment still playing out finishes before the table moves on.
	_draining = _held and _wait > 0.0
	if not _draining:
		_held = false
		drained.emit()


## A play waits only until its cards land when its score is counted next.
func _step_for(event: RunEvent) -> float:
	var played_cards: bool = (
		event.round_event != null and event.round_event.type == RoundEvent.Type.PLAYED
	)
	return play_wait if played_cards and play_wait >= 0.0 else step


func _ends_round(event: RunEvent) -> bool:
	return event.round_event != null and event.round_event.type == RoundEvent.Type.ROUND_ENDED


## Only bids, plays, passes and trick ends take a step; bookkeeping goes at once.
func _shows(event: RunEvent) -> bool:
	if event.type != RunEvent.Type.ROUND:
		return event.type in [RunEvent.Type.BID, RunEvent.Type.LANDLORD_CHOSEN]
	return (
		event.round_event.type
		in [RoundEvent.Type.PLAYED, RoundEvent.Type.PASSED, RoundEvent.Type.TRICK_WON]
	)

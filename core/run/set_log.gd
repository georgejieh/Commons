class_name SetLog
extends RefCounted
## The current Set's events, appended in order and cleared when a Set starts, so the
## log never outgrows one Set. Each round is folded into the Set's summary as it ends,
## so a run resumed mid-Set keeps the summary of the rounds before.

## Called with each event in order, so a view sees events across Set boundaries.
var on_add: Callable = Callable()

var _events: Array[RunEvent] = []
var _round_start: int = 0
## How many events on_add has seen. Banking and meters append to events() directly, so
## they reach on_add at the next add or flush.
var _flushed: int = 0


func events() -> Array[RunEvent]:
	return _events


func add(event: RunEvent) -> void:
	_events.append(event)
	flush()


## Hands on_add every event it hasn't seen.
func flush() -> void:
	while _flushed < _events.size():
		_flushed += 1
		if on_add.is_valid():
			on_add.call(_events[_flushed - 1])


## Starts the Set's summary as the run's last.
func start_set(state: RunState, set_number: int) -> void:
	flush()
	_events.clear()
	_flushed = 0
	_round_start = 0
	state.summaries.append(SetSummary.new(set_number))


func start_round() -> void:
	_round_start = _events.size()


func end_round(state: RunState, player: int) -> void:
	var round_events: Array[RunEvent] = _events.slice(_round_start)
	SummaryFold.fold_round(state.summaries[-1], round_events, player, state.table)
	ObservationFold.fold_round(state.observations, round_events, player, state.table)

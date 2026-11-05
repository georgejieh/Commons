class_name SetLog
extends RefCounted
## The current Set's events, appended in order and cleared when a Set starts, so the
## log never outgrows one Set. Each round is folded into the Set's summary as it ends,
## so a run resumed mid-Set keeps the summary of the rounds before.

var _events: Array[RunEvent] = []
var _round_start: int = 0


func events() -> Array[RunEvent]:
	return _events


func add(event: RunEvent) -> void:
	_events.append(event)


## Starts the Set's summary as the run's last.
func start_set(state: RunState, set_number: int) -> void:
	_events.clear()
	_round_start = 0
	state.summaries.append(SetSummary.new(set_number))


func start_round() -> void:
	_round_start = _events.size()


func end_round(state: RunState, player: int) -> void:
	var round_events: Array[RunEvent] = _events.slice(_round_start)
	SummaryFold.fold_round(state.summaries[-1], round_events, player, state.table)

class_name RunController
extends Node
## The one way the UI touches a run. It owns the run loop and its state, takes the UI's
## commands, and re-emits the loop's domain events as signals. Queries hand out copies,
## so a view can read the run but never change it.

signal event_emitted(event: RunEvent)
## The loop now waits on this RunLoop.Awaiting value.
signal awaiting_changed(awaiting: int)
## A command the loop refused, with its RunLoop.Reason.
signal command_refused(command: String, reason: int)

## Every command the UI may send. Selection is the hand model's, not the run's.
const COMMANDS: Array[String] = ["bid", "swap", "play", "pass", "declare_need", "finish_set"]

var _loop: RunLoop
## Called with the loop at every state boundary, for autosaves.
var _on_boundary: Callable = Callable()


## Starts a new run from seed, with one bot config per seat.
func start_run(
	seed_value: int,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	on_boundary: Callable = Callable()
) -> void:
	_on_boundary = on_boundary
	_attach(RunLoop.new(RunState.new(seed_value), configs, sets))
	_loop.start_set()
	_loop.set_log.flush()
	awaiting_changed.emit(_loop.awaiting())


## Takes over a loop that was resumed from a save.
func resume(loop: RunLoop, on_boundary: Callable = Callable()) -> void:
	_on_boundary = on_boundary
	_attach(loop)
	awaiting_changed.emit(_loop.awaiting())


func has_run() -> bool:
	return _loop != null


func bid(claim: bool) -> int:
	return _finish("bid", _loop.player_bid(claim))


func swap(hand_ids: Array[int], plot_ids: Array[int]) -> int:
	return _finish("swap", _loop.player_swap(hand_ids.duplicate(), plot_ids.duplicate()))


func play(card_ids: Array[int]) -> int:
	return _finish("play", _loop.player_play(card_ids.duplicate()))


func pass_turn() -> int:
	var none: Array[int] = []
	return _finish("pass", _loop.player_play(none))


func declare_need(need: int) -> int:
	return _finish("declare_need", _loop.player_need(need))


## Moves past a finished Set to the next one, or to the run's end.
func finish_set() -> int:
	return _finish("finish_set", _loop.next_set())


## The current Set's events so far, for a view that joins mid-Set.
func set_events() -> Array[RunEvent]:
	return _loop.events().duplicate()


func awaiting() -> RunLoop.Awaiting:
	return _loop.awaiting()


## The player's seat view of the current round, or null between rounds.
func seat_view() -> SeatView:
	var round_state: RoundState = _loop.round_state()
	if round_state == null:
		return null
	return round_state.view_for(RunLoop.PLAYER)


## Copies of the player's cards.
func player_cards() -> Array[CardInstance]:
	return _loop.player_cards()


## The rules and rank order the player plays under.
func player_table() -> BotTable:
	return _loop.seat_table(RunLoop.PLAYER)


## The legal moves when the player must play, else none.
func legal_moves() -> Array[Pattern]:
	if _loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		return []
	return _loop.round_state().legal_moves()


## The player's card IDs for a pattern, by the fixed selection policy.
func card_ids_for(pattern: Pattern) -> Array[int]:
	return _loop.round_state().action_for(pattern).card_ids.duplicate()


func target() -> float:
	return _loop.target()


## A copy of the run state, for display.
func state_copy() -> RunState:
	return RunState.from_dict(_loop.state.to_dict())


func _attach(loop: RunLoop) -> void:
	_loop = loop
	_loop.set_log.on_add = func(event: RunEvent) -> void: event_emitted.emit(event)
	_loop.on_boundary = _on_boundary


func _finish(command: String, reason: RunLoop.Reason) -> int:
	_loop.set_log.flush()
	if reason != RunLoop.Reason.OK:
		command_refused.emit(command, reason)
	else:
		awaiting_changed.emit(_loop.awaiting())
	return reason

class_name RunFlow
extends RefCounted
## The run's states and the one table of moves between them. Any other move is refused
## with a reason code and changes nothing.

enum State {
	RUN_START,
	SET_INTRO,
	BIDDING,
	ROUND_PLAY,
	ROUND_END,
	SET_END,
	SHOP,
	EVENT,
	YEAR_END,
	RUN_END,
	REEDUCATION,
}
enum Reason { OK, ILLEGAL_TRANSITION }

## Bidding loops on itself for a redeal. A round ends in bidding when the landlord lost,
## or straight into play when the seat is kept. Death can end the run at any boundary
## where a meter moves.
const TRANSITIONS: Dictionary[State, Array] = {
	State.RUN_START: [State.SET_INTRO],
	State.SET_INTRO: [State.BIDDING],
	State.BIDDING: [State.BIDDING, State.ROUND_PLAY],
	State.ROUND_PLAY: [State.ROUND_END],
	State.ROUND_END: [State.BIDDING, State.ROUND_PLAY, State.SET_END, State.RUN_END],
	State.SET_END: [State.SHOP, State.REEDUCATION, State.RUN_END],
	State.SHOP: [State.EVENT, State.SET_INTRO, State.YEAR_END, State.RUN_END],
	State.EVENT: [State.SET_INTRO, State.YEAR_END, State.RUN_END],
	State.YEAR_END: [State.SET_INTRO, State.RUN_END],
	State.REEDUCATION: [State.SET_INTRO, State.YEAR_END, State.RUN_END],
	State.RUN_END: [],
}

var _state: State


func _init(start: State = State.RUN_START) -> void:
	_state = start


static func allows(from: State, to: State) -> bool:
	return TRANSITIONS[from].has(to)


func state() -> State:
	return _state


func move(to: State) -> Reason:
	if not allows(_state, to):
		return Reason.ILLEGAL_TRANSITION
	_state = to
	return Reason.OK

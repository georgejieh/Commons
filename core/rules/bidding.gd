class_name Bidding
extends RefCounted
## Call and grab. Seats take turns calling until one calls. Each other seat that has not
## passed then gets one chance to grab, and each grab multiplies the stake. The last
## seat to claim is the landlord. If everyone passes, the hand is redealt.

enum Phase { CALLING, GRABBING, DONE }
enum Reason { OK, OUT_OF_TURN, FINISHED }

const DEFAULT_PARAMS: BidParams = preload("res://data/rules/default_bid.tres")

var _params: BidParams
var _phase: Phase = Phase.CALLING
var _seat: int
var _landlord: int = Seats.NONE
var _stake: int
var _pending: Array[int] = []
var _decided: int = 0


func _init(first_seat: int, params: BidParams = DEFAULT_PARAMS) -> void:
	_params = params
	_seat = first_seat
	_stake = params.base_stake


func phase() -> Phase:
	return _phase


## The seat that must act, or Seats.NONE once bidding is over.
func seat_to_act() -> int:
	return Seats.NONE if _phase == Phase.DONE else _seat


func landlord() -> int:
	return _landlord


func stake() -> int:
	return _stake


## True when everyone passed and the hand must be redealt.
func needs_redeal() -> bool:
	return _phase == Phase.DONE and _landlord == Seats.NONE


## claim means call while calling and grab while grabbing. False is a pass.
func act(seat: int, claim: bool) -> Reason:
	if _phase == Phase.DONE:
		return Reason.FINISHED
	if seat != _seat:
		return Reason.OUT_OF_TURN
	if _phase == Phase.CALLING:
		_act_calling(claim)
	else:
		_act_grabbing(claim)
	return Reason.OK


func _act_calling(claim: bool) -> void:
	_decided += 1
	if claim:
		_landlord = _seat
		var seat: int = Seats.next(_seat)
		for _left: int in Seats.COUNT - _decided:
			_pending.append(seat)
			seat = Seats.next(seat)
		_phase = Phase.GRABBING
		_advance_grabs()
	elif _decided == Seats.COUNT:
		_phase = Phase.DONE
	else:
		_seat = Seats.next(_seat)


func _act_grabbing(claim: bool) -> void:
	if claim:
		_landlord = _seat
		_stake *= _params.grab_multiplier
	_advance_grabs()


func _advance_grabs() -> void:
	if _pending.is_empty():
		_phase = Phase.DONE
	else:
		_seat = _pending.pop_front()

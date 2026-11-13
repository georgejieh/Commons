class_name TableMoments
extends RefCounted
## Turns run events into the table's showy beats: each bid stamped at the seat that
## made it and kept on that seat until the landlord is chosen, passes, a play's points
## flying to the ledger, and the audit of every claim on the Commons. It only shows
## what happened; the ledger, seats and meters hold the same facts at rest.

const SOFT: Color = Color("5a4a36")
const GRAIN: Color = Color("8a5a12")
const PASS_SIZE: int = 40

var _fx: TableFx
var _slip: AuditSlip
var _ledger: Ledger
var _seats: Dictionary[int, SeatPanel] = {}
## Where a seat's stamps land and where the trick pile's middle is, on screen.
var _seat_at: Callable
var _pile_at: Callable
## The seat holding the landlord bid, and each seat's last bid as a string key.
var _holder: int = Seats.NONE
var _bids: Dictionary[int, String] = {}


func setup(
	fx: TableFx,
	slip: AuditSlip,
	ledger: Ledger,
	seats: Dictionary[int, SeatPanel],
	seat_at: Callable,
	pile_at: Callable
) -> void:
	_fx = fx
	_slip = slip
	_ledger = ledger
	_seats = seats
	_seat_at = seat_at
	_pile_at = pile_at


## Shows event. quiet keeps the bookkeeping and drops the show, for replays.
func on_event(event: RunEvent, quiet: bool = false) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_holder = Seats.NONE
			_bids.clear()
			_slip.clear()
		RunEvent.Type.BID:
			_on_bid(event.seat, event.value == 1, quiet)
		RunEvent.Type.LANDLORD_CHOSEN:
			_bids.clear()
		RunEvent.Type.ROUND:
			var passed: bool = event.round_event.type == RoundEvent.Type.PASSED
			if passed and not quiet:
				var at: Vector2 = _seat_at.call(event.round_event.seat)
				_fx.stamp(TranslationServer.translate("stamp.pass"), at, SOFT, PASS_SIZE)
		RunEvent.Type.PLAY_SCORED:
			if not quiet and event.amount > 0.0:
				var to: Vector2 = _ledger.amount_center(event.seat)
				_fx.fly("+" + Strings.score(event.amount), _pile_at.call(), to, GRAIN)
		RunEvent.Type.NEED_DECLARED:
			if not quiet:
				_slip.claim(event.seat, event.value)
		RunEvent.Type.AUDITED:
			_slip.audited(event.seat, event.value == 1)
		RunEvent.Type.SHARE_PAID:
			if not quiet:
				_slip.paid(event.seat, event.value)


## What a seat last did in the bidding, as a string key, or "" outside it.
func bid_key(seat: int) -> String:
	return _bids.get(seat, "")


func _on_bid(seat: int, claim: bool, quiet: bool) -> void:
	var key: String = "pass"
	if claim:
		key = "call" if _holder == Seats.NONE else "grab"
		_holder = seat
	_bids[seat] = "bid." + key
	if _seats.has(seat):
		_seats[seat].set_bid(TranslationServer.translate("bid." + key))
	if quiet:
		return
	var stamp_key: String = "stamp.no_call" if key == "pass" else "stamp." + key
	var color: Color = ScreenKit.RED if claim else SOFT
	_fx.stamp(TranslationServer.translate(stamp_key), _seat_at.call(seat), color)

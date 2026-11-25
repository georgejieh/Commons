class_name MarkDesk
extends RefCounted
## A shop's desk that marks one deck card of the player's choice for the rest of the run
## (ADR 0041). The state store's offers one enhancement each visit, drawn from all of them
## on a stream of its own seeded from the run and the visit, so the offer shifts no other
## draw and a save that replays the visit draws it again. The black market's stamps the
## card as the player's. Either is used at most once a visit, at the counter's price under
## any raise the books made (ADR 0022), and is shut through the arrival. A use is a
## recorded command, so nothing here is saved.

enum Reason { OK, CLOSED, USED, TOO_POOR, NO_SUCH_CARD, ALREADY_MARKED }

## The enhancement on offer, or CardInstance.NO_ID at a desk that stamps.
var offer: String = CardInstance.NO_ID
## True while the desk takes a card this visit: a counter whose data gives it no desk,
## and the arrival, never open one.
var is_open: bool = false

var _state: RunState
var _params: ShopParams
var _used: bool = false


func _init(state: RunState, params: ShopParams) -> void:
	_state = state
	_params = params


## True at the desk that stamps cards rather than enhancing them.
func stamps() -> bool:
	return _params.desk_stamps


## Opens the desk for a visit, drawing the state store's enhancement. shut keeps it closed,
## as through the arrival.
func open(shut: bool) -> void:
	_used = false
	offer = CardInstance.NO_ID
	is_open = _params.desk_price > 0 and not shut
	if not is_open or stamps():
		return
	var visit: int = (_state.year - 1) * SetConfig.SETS_PER_YEAR + _state.set_index
	var key: String = "mark_desk:%d" % visit
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(_state.run_seed, key))
	var kinds: Array[String] = CardInstance.ENHANCEMENTS
	offer = kinds[stream.next_int(0, kinds.size() - 1)]


func price() -> int:
	return RunBooks.priced(_state, _params.desk_price)


func used() -> bool:
	return _used


## Why the desk cannot mark the deck card for seat now, or OK. A card that already
## carries the mark is refused, so a use is never wasted.
func check(card_id: int, seat: int) -> Reason:
	if not is_open:
		return Reason.CLOSED
	if _used:
		return Reason.USED
	if card_id < 0 or card_id >= Deck.SIZE:
		return Reason.NO_SUCH_CARD
	if _carries(card_id, seat):
		return Reason.ALREADY_MARKED
	return Reason.TOO_POOR if _state.coupons < price() else Reason.OK


## True when the deck card already carries the mark this desk gives.
func _carries(card_id: int, seat: int) -> bool:
	if stamps():
		return _state.card_marks.stamps.get(card_id, CardInstance.NO_OWNER) == seat
	return _state.card_marks.enhancements.get(card_id, CardInstance.NO_ID) == offer


## Marks the deck card for the run, in place of any enhancement it had, and takes the
## price. seat is the player's, whose stamp the black market's desk presses.
func mark(card_id: int, seat: int) -> Reason:
	var reason: Reason = check(card_id, seat)
	if reason != Reason.OK:
		return reason
	_state.coupons -= price()
	_used = true
	var card: CardInstance = _state.deck.card(card_id)
	if stamps():
		CardMarks.stamp(_state, card, seat)
	else:
		CardMarks.enhance(_state, card, offer)
	return Reason.OK

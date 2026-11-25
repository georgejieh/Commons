class_name CardOffers
extends RefCounted
## The cards a stall offers one visit, each a rank and a suit and perhaps an enhancement,
## at a price by its rank and its mark under any raise the books made (ADR 0022). The
## black market's plot stall (P4.10) and the state store's deck stall (ADR 0042) each
## offer through one, from their own CardStallParams. An offer is drawn as its rank, then
## its suit, then, where the data marks some, whether it carries an enhancement and which,
## so a stall that marks none draws as the plot stall always has. Offers are never saved:
## a save in the shop replays the visit, which draws them again.

const SOLD: int = Ranks.INVALID
const PERCENT: int = 100

var _state: RunState
var _params: CardStallParams
## The rank, suit and enhancement offered in each slot; the rank is SOLD once bought.
var _ranks: Array[int] = []
var _suits: Array[int] = []
var _marks: Array[String] = []


func _init(state: RunState, params: CardStallParams) -> void:
	_state = state
	_params = params


## Draws a visit's offers on stream, each rank from those open of the data's.
func draw(stream: RandomStream, open: Array[int]) -> void:
	clear()
	if open.is_empty():
		return
	for offer: int in _params.offers:
		_ranks.append(open[stream.next_int(0, open.size() - 1)])
		var suit: int = stream.next_int(0, Deck.SUITS - 1)
		if not _params.suits.is_empty():
			suit = _params.suits[offer % _params.suits.size()]
		_suits.append(suit)
		var mark: String = CardInstance.NO_ID
		if _params.marked_percent > 0 and stream.next_int(0, PERCENT - 1) < _params.marked_percent:
			var kinds: Array[String] = CardInstance.ENHANCEMENTS
			mark = kinds[stream.next_int(0, kinds.size() - 1)]
		_marks.append(mark)


func clear() -> void:
	_ranks.clear()
	_suits.clear()
	_marks.clear()


## The ranks the data offers, in its order.
func ranks() -> Array[int]:
	return _params.ranks


func count() -> int:
	return _ranks.size()


## The rank offered in a slot, or SOLD.
func rank(slot: int) -> int:
	return _ranks[slot]


func suit(slot: int) -> int:
	return _suits[slot]


## The enhancement the slot's card carries, or CardInstance.NO_ID.
func enhancement(slot: int) -> String:
	return _marks[slot]


func has_slot(slot: int) -> bool:
	return slot >= 0 and slot < _ranks.size()


func price(slot: int) -> int:
	var cost: int = _params.costs[_params.ranks.find(_ranks[slot])]
	if _marks[slot] != CardInstance.NO_ID:
		cost += _params.mark_cost
	return RunBooks.priced(_state, cost)


## Takes the slot's price from the coupons and marks it sold.
func sell(slot: int) -> void:
	_state.coupons -= price(slot)
	_ranks[slot] = SOLD

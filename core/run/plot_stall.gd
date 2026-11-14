class_name PlotStall
extends RefCounted
## Cards for the private plot, sold at the black market (P4.10). Each visit offers a few
## cards, their ranks and suits drawn on the shop stream from the ranks the data lists.
## A bought card goes into the plot under a new plot ID, if the plot has room. Like the
## counters' stock, the offers are never saved: a save in the shop replays the visit.

enum Reason { OK, NO_SUCH_SLOT, SOLD_OUT, TOO_POOR, PLOT_FULL }

const SOLD: int = -1
const SUITS: int = 4

var _state: RunState
var _params: PlotUpgradeParams
var _run: RunParams
## The rank and suit offered in each slot; the rank is SOLD once bought.
var _ranks: Array[int] = []
var _suits: Array[int] = []


func _init(state: RunState, params: PlotUpgradeParams, run: RunParams) -> void:
	_state = state
	_params = params
	_run = run


## Starts a visit with fresh offers.
func open() -> void:
	_ranks.clear()
	_suits.clear()
	if _params.card_ranks.is_empty():
		return
	var stream: RandomStream = _state.streams.stream(RandomStreams.SHOP)
	for _offer: int in _params.card_offers:
		_ranks.append(_params.card_ranks[stream.next_int(0, _params.card_ranks.size() - 1)])
		_suits.append(stream.next_int(0, SUITS - 1))


func count() -> int:
	return _ranks.size()


## The rank offered in a slot, or SOLD.
func rank(slot: int) -> int:
	return _ranks[slot]


func suit(slot: int) -> int:
	return _suits[slot]


func price(slot: int) -> int:
	return _params.card_costs[_params.card_ranks.find(_ranks[slot])]


func check_buy(slot: int) -> Reason:
	if slot < 0 or slot >= _ranks.size():
		return Reason.NO_SUCH_SLOT
	if _ranks[slot] == SOLD:
		return Reason.SOLD_OUT
	if _state.inventory.plot.size() >= PlotSwap.capacity(_state, _run):
		return Reason.PLOT_FULL
	if _state.coupons < price(slot):
		return Reason.TOO_POOR
	return Reason.OK


func buy(slot: int) -> Reason:
	var reason: Reason = check_buy(slot)
	if reason != Reason.OK:
		return reason
	_state.coupons -= price(slot)
	var card: CardInstance = CardInstance.new(
		_state.take_plot_id(), _ranks[slot], _suits[slot], CardInstance.Origin.PLOT
	)
	PlotSwap.store(_state, card, _run)
	_ranks[slot] = SOLD
	return Reason.OK

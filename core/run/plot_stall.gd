class_name PlotStall
extends RefCounted
## Cards for the private plot, sold at the black market. Each visit offers a few
## cards through CardOffers, drawn on the shop stream from the ranks the data lists. A
## bought card goes into the plot under a new plot ID, if the plot has room.

enum Reason { OK, NO_SUCH_SLOT, SOLD_OUT, TOO_POOR, PLOT_FULL }

var offers: CardOffers

var _state: RunState
var _run: RunParams


func _init(state: RunState, params: CardStallParams, run: RunParams) -> void:
	_state = state
	_run = run
	offers = CardOffers.new(state, params)


## Starts a visit with fresh offers.
func open() -> void:
	offers.draw(_state.streams.stream(RandomStreams.SHOP), offers.ranks())


func check_buy(slot: int) -> Reason:
	if not offers.has_slot(slot):
		return Reason.NO_SUCH_SLOT
	if offers.rank(slot) == CardOffers.SOLD:
		return Reason.SOLD_OUT
	if _state.inventory.plot.size() >= PlotSwap.capacity(_state, _run):
		return Reason.PLOT_FULL
	if _state.coupons < offers.price(slot):
		return Reason.TOO_POOR
	return Reason.OK


func buy(slot: int) -> Reason:
	var reason: Reason = check_buy(slot)
	if reason != Reason.OK:
		return reason
	var card: CardInstance = CardInstance.new(
		_state.take_plot_id(), offers.rank(slot), offers.suit(slot), CardInstance.Origin.PLOT
	)
	offers.sell(slot)
	PlotSwap.store(_state, card, _run)
	return Reason.OK

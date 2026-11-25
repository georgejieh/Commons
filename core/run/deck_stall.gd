class_name DeckStall
extends RefCounted
## The state store's stall of cards for the communal deck (ADR 0042), the counterpart of
## the black market's plot stall: a few cards a visit through CardOffers, some carrying an
## enhancement, never the player's stamp. Buying one names the deck card it replaces
## (DeckExchange). The offers are drawn on a stream of their own seeded from the run and
## the visit, as the desk's offer is, so they shift no other draw and a save that replays
## the visit draws them again, from the ranks the deck still has room for. The arrival
## opens none. A purchase is a recorded command, so nothing here is saved.

## True while the stall sells this visit.
var is_open: bool = false
var offers: CardOffers

var _state: RunState
var _run: RunParams


func _init(state: RunState, params: CardStallParams, run: RunParams) -> void:
	_state = state
	_run = run
	offers = CardOffers.new(state, params)


## Opens the stall for a visit with fresh offers. shut keeps it closed, as through the
## arrival.
func open(shut: bool) -> void:
	offers.clear()
	is_open = not shut
	if not is_open:
		return
	var visit: int = (_state.year - 1) * SetConfig.SETS_PER_YEAR + _state.set_index
	var key: String = "deck_stall:%d" % visit
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(_state.run_seed, key))
	offers.draw(stream, DeckExchange.open_ranks(_state, _run, offers.ranks()))


## The most cards of one rank the deck may hold.
func most() -> int:
	return _run.deck_rank_most


## Why the slot's card could not be bought now, before any deck card is named, or OK.
func check(slot: int) -> RunShop.Reason:
	if not is_open:
		return RunShop.Reason.CLOSED
	if not offers.has_slot(slot):
		return RunShop.Reason.NO_SUCH_SLOT
	if offers.rank(slot) == CardOffers.SOLD:
		return RunShop.Reason.SOLD_OUT
	var room: RunShop.Reason = DeckExchange.check_in(_state, _run, offers.rank(slot))
	if room != RunShop.Reason.OK:
		return room
	return RunShop.Reason.TOO_POOR if _state.coupons < offers.price(slot) else RunShop.Reason.OK


## Why the slot's card could not replace the deck card in out, or OK.
func check_exchange(slot: int, out: int) -> RunShop.Reason:
	var reason: RunShop.Reason = check(slot)
	if reason != RunShop.Reason.OK:
		return reason
	return DeckExchange.check_out(_state, out)


## Buys the slot's card and puts it in the deck in place of the card in out.
func buy(slot: int, out: int) -> RunShop.Reason:
	var reason: RunShop.Reason = check_exchange(slot, out)
	if reason != RunShop.Reason.OK:
		return reason
	DeckExchange.apply(_state, out, offers.rank(slot), offers.suit(slot), offers.enhancement(slot))
	offers.sell(slot)
	return RunShop.Reason.OK

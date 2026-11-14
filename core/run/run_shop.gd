class_name RunShop
extends RefCounted
## One counter between Sets: the state store or the black market (P4.10). Stock is drawn
## on the shop stream by rarity weight from the counter's pool, leaving out what the
## player holds and what the counter has run out of, and bought with coupons at the
## counter's price. A reroll draws new stock for a price that rises with each reroll in
## the visit. Stock is never saved: a save in the shop replays the visit from the Set's
## end, which draws the same stock.

enum Reason { OK, NO_SUCH_SLOT, SOLD_OUT, TOO_POOR, CADRES_FULL }

const SOLD: String = ""
const PERCENT: int = 100

var _state: RunState
var _params: ShopParams
var _pool: Array[ModifierDef]
## Slots lost while rationing is in force (P4.1).
var _ration_cut: int
var _stock: Array[String] = []
var _rerolls: int = 0


func _init(
	state: RunState, params: ShopParams, pool: Array[ModifierDef], ration_cut: int = 0
) -> void:
	_state = state
	_params = params
	_pool = pool
	_ration_cut = ration_cut


## Slots this visit offers: fewer while rationing is in force.
func slot_count() -> int:
	return maxi(_params.slots - (_ration_cut if _state.rationed else 0), 0)


## Starts a visit with fresh stock.
func open() -> void:
	_rerolls = 0
	_restock()


## IDs per slot; SOLD marks a slot already bought.
func stock() -> Array[String]:
	return _stock.duplicate()


## The counter's price for a slot: the item's cost at price_percent, rounded up.
func price(slot: int) -> int:
	return (_definition(_stock[slot]).cost * _params.price_percent + PERCENT - 1) / PERCENT


## How many more of an item this counter will sell this run, or -1 when unlimited.
func left(modifier_id: String) -> int:
	if _params.stock_per_item <= 0:
		return -1
	return maxi(_params.stock_per_item - int(_state.store_sold.get(modifier_id, 0)), 0)


func reroll_price() -> int:
	return _params.reroll_base + _rerolls * _params.reroll_step


## True when a reroll could put something else on the counter: there is more to offer
## than the counter has slots.
func reroll_changes() -> bool:
	var open: int = 0
	for definition: ModifierDef in _pool:
		if not _state.inventory.cadres.has(definition.id) and left(definition.id) != 0:
			open += 1
	return open > slot_count()


## True while the player's board can take another Cadre.
func has_room() -> bool:
	return _state.inventory.cadres.size() < _params.cadre_slots


func check_buy(slot: int) -> Reason:
	if slot < 0 or slot >= _stock.size():
		return Reason.NO_SUCH_SLOT
	if _stock[slot] == SOLD:
		return Reason.SOLD_OUT
	if not has_room():
		return Reason.CADRES_FULL
	if _state.coupons < price(slot):
		return Reason.TOO_POOR
	return Reason.OK


func buy(slot: int) -> Reason:
	var reason: Reason = check_buy(slot)
	if reason != Reason.OK:
		return reason
	_state.coupons -= price(slot)
	_state.inventory.cadres.append(_stock[slot])
	if _params.stock_per_item > 0:
		_state.store_sold[_stock[slot]] = int(_state.store_sold.get(_stock[slot], 0)) + 1
	_stock[slot] = SOLD
	return Reason.OK


func reroll() -> Reason:
	if _state.coupons < reroll_price():
		return Reason.TOO_POOR
	_state.coupons -= reroll_price()
	_rerolls += 1
	_restock()
	return Reason.OK


func _restock() -> void:
	# What the player holds, and what this counter has sold out of, is not offered.
	var closed: Array[String] = _state.inventory.cadres.duplicate()
	for definition: ModifierDef in _pool:
		if left(definition.id) == 0:
			closed.append(definition.id)
	_stock = draw(
		_pool,
		slot_count(),
		closed,
		_params.rarity_weights,
		_state.streams.stream(RandomStreams.SHOP)
	)


func _definition(modifier_id: String) -> ModifierDef:
	for definition: ModifierDef in _pool:
		if definition.id == modifier_id:
			return definition
	return null


## Draws up to count distinct IDs not in owned, each weighted by its rarity's weight.
static func draw(
	pool: Array[ModifierDef],
	count: int,
	owned: Array[String],
	weights: Array[int],
	stream: RandomStream
) -> Array[String]:
	var open: Array[ModifierDef] = pool.filter(
		func(definition: ModifierDef) -> bool: return not owned.has(definition.id)
	)
	var drawn: Array[String] = []
	while drawn.size() < count and not open.is_empty():
		var total: int = 0
		for definition: ModifierDef in open:
			total += weights[definition.rarity]
		var roll: int = stream.next_int(0, total - 1)
		for index: int in open.size():
			roll -= weights[open[index].rarity]
			if roll < 0:
				drawn.append(open[index].id)
				open.remove_at(index)
				break
	return drawn

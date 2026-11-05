class_name RunShop
extends RefCounted
## The state store between Sets. Stock is drawn on the shop stream by rarity weight from
## the Cadres the player doesn't hold, and bought with coupons. A reroll draws new stock
## for a price that rises with each reroll in the visit. Stock is never saved: a save in
## the shop replays the visit from the Set's end, which draws the same stock.

enum Reason { OK, NO_SUCH_SLOT, SOLD_OUT, TOO_POOR, CADRES_FULL }

const SOLD: String = ""

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


func price(slot: int) -> int:
	return _definition(_stock[slot]).cost


func reroll_price() -> int:
	return _params.reroll_base + _rerolls * _params.reroll_step


func check_buy(slot: int) -> Reason:
	if slot < 0 or slot >= _stock.size():
		return Reason.NO_SUCH_SLOT
	if _stock[slot] == SOLD:
		return Reason.SOLD_OUT
	if _state.inventory.cadres.size() >= _params.cadre_slots:
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
	_stock = draw(
		_pool,
		slot_count(),
		_state.inventory.cadres,
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

class_name RunShop
extends RefCounted
## One counter between Sets: the state store or the black market (P4.10). Stock is drawn
## on the shop stream by rarity weight from the counter's pool, leaving out what the
## player holds and what the counter has run out of, and bought with coupons at the
## counter's price. A reroll draws new stock for a price that rises with each reroll in
## the visit. Stock is never saved: a save in the shop replays the visit from the Set's
## end, which draws the same stock. A counter with Directive slots also offers Directives
## (ADR 0021), drawn evenly after every Cadre on the stream and redrawn by the same
## reroll; one whose whole family is at the top level is not offered.

enum Reason { OK, NO_SUCH_SLOT, SOLD_OUT, TOO_POOR, CADRES_FULL, LEVELS_MAXED }

const SOLD: String = ""
const PERCENT: int = 100

var _state: RunState
var _params: ShopParams
var _pool: Array[ModifierDef]
## Slots lost while rationing is in force (P4.1).
var _ration_cut: int
var _stock: Array[String] = []
var _rerolls: int = 0
var _directives: Array[DirectiveDef]
var _directive_stock: Array[String] = []


func _init(
	state: RunState,
	params: ShopParams,
	pool: Array[ModifierDef],
	ration_cut: int = 0,
	directives: Array[DirectiveDef] = []
) -> void:
	_state = state
	_params = params
	_pool = pool
	_ration_cut = ration_cut
	_directives = directives


## Slots this visit offers: fewer while rationing is in force.
func slot_count() -> int:
	return maxi(_params.slots - (_ration_cut if _state.rationed else 0), 0)


## Starts a visit with fresh Cadres. The Directives are drawn by stock_directives().
func open() -> void:
	_rerolls = 0
	_directive_stock.clear()
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


## True when a reroll could put something else on the counter: more Cadres to offer
## than slots while the board has room for one, or more Directives than their slots.
func reroll_changes() -> bool:
	var open: int = 0
	for definition: ModifierDef in _pool:
		if not _state.inventory.cadres.has(definition.id) and left(definition.id) != 0:
			open += 1
	if has_room() and open > slot_count():
		return true
	return _open_directives().size() > _params.directive_slots


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
	stock_directives()
	return Reason.OK


## Directive IDs per slot; SOLD marks one already issued.
func directive_stock() -> Array[String]:
	return _directive_stock.duplicate()


func directive_price(slot: int) -> int:
	var cost: int = _directive(_directive_stock[slot]).cost
	return (cost * _params.price_percent + PERCENT - 1) / PERCENT


func check_directive(slot: int) -> Reason:
	if slot < 0 or slot >= _directive_stock.size():
		return Reason.NO_SUCH_SLOT
	if _directive_stock[slot] == SOLD:
		return Reason.SOLD_OUT
	if _is_maxed(_directive(_directive_stock[slot])):
		return Reason.LEVELS_MAXED
	if _state.coupons < directive_price(slot):
		return Reason.TOO_POOR
	return Reason.OK


## Issues a Directive: every hand type in its family rises one level at once.
func buy_directive(slot: int) -> Reason:
	var reason: Reason = check_directive(slot)
	if reason != Reason.OK:
		return reason
	_state.coupons -= directive_price(slot)
	for type: int in _directive(_directive_stock[slot]).hand_types:
		_state.hand_levels.raise(type as Pattern.Type)
	_directive_stock[slot] = SOLD
	return Reason.OK


## Draws the visit's Directives. The run loop calls it once every counter has drawn its
## Cadres and cards, so Directives leave the stock a seed drew before them as it was.
func stock_directives() -> void:
	var open: Array[DirectiveDef] = _open_directives()
	_directive_stock.clear()
	var stream: RandomStream = _state.streams.stream(RandomStreams.SHOP)
	while _directive_stock.size() < _params.directive_slots and not open.is_empty():
		var index: int = stream.next_int(0, open.size() - 1)
		_directive_stock.append(open[index].id)
		open.remove_at(index)


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


## The Directives with a hand type still below the top level, in pool order.
func _open_directives() -> Array[DirectiveDef]:
	return _directives.filter(
		func(directive: DirectiveDef) -> bool: return not _is_maxed(directive)
	)


func _is_maxed(directive: DirectiveDef) -> bool:
	for type: int in directive.hand_types:
		if not _state.hand_levels.is_max(type as Pattern.Type):
			return false
	return true


func _directive(directive_id: String) -> DirectiveDef:
	for directive: DirectiveDef in _directives:
		if directive.id == directive_id:
			return directive
	return null


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

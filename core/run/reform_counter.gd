class_name ReformCounter
extends RefCounted
## The state store's Reforms (ADR 0021): reform_offers of them drawn evenly from the pool
## after every other draw on the shop stream, never one the player holds, redrawn by the
## counter's reroll and bought at the counter's price. A bought Reform lasts the run.

## The stock marker for a slot whose Reform is already bought.
const SOLD: String = ""

var _state: RunState
var _params: ShopParams
var _pool: Array[ReformDef]
var _stock: Array[String] = []


func _init(state: RunState, params: ShopParams, pool: Array[ReformDef]) -> void:
	_state = state
	_params = params
	_pool = pool


## Reform IDs per slot; SOLD marks one already bought.
func stock() -> Array[String]:
	return _stock.duplicate()


## What the Reform in the slot costs, with the run's price raises.
func price(slot: int) -> int:
	return RunShop.price_of(_state, _params, _reform(_stock[slot]).cost)


## True when a reroll could offer another Reform.
func reroll_changes() -> bool:
	return _params.reform_offers > 0 and _open().size() > _params.reform_offers


## Why the slot cannot be bought, or OK: no slot, sold out or already held, or too poor.
func check(slot: int) -> RunShop.Reason:
	if slot < 0 or slot >= _stock.size():
		return RunShop.Reason.NO_SUCH_SLOT
	if _stock[slot] == SOLD or _state.reforms.has(_stock[slot]):
		return RunShop.Reason.SOLD_OUT
	if _state.coupons < price(slot):
		return RunShop.Reason.TOO_POOR
	return RunShop.Reason.OK


## Enacts the Reform in slot for the rest of the run.
func buy(slot: int) -> RunShop.Reason:
	var reason: RunShop.Reason = check(slot)
	if reason != RunShop.Reason.OK:
		return reason
	_state.coupons -= price(slot)
	_state.reforms.append(_stock[slot])
	_stock[slot] = SOLD
	return RunShop.Reason.OK


## Empties the counter's stock, as when the visit ends.
func clear() -> void:
	_stock.clear()


## Draws the visit's Reforms evenly from those still open. The run loop calls it last on
## the shop stream, so Reforms leave every other draw a seed made as it was.
func draw() -> void:
	var open: Array[ReformDef] = _open()
	_stock.clear()
	var stream: RandomStream = _state.streams.stream(RandomStreams.SHOP)
	while _stock.size() < _params.reform_offers and not open.is_empty():
		var index: int = stream.next_int(0, open.size() - 1)
		_stock.append(open[index].id)
		open.remove_at(index)


## The Reforms that can be offered: those not held, in pool order.
func _open() -> Array[ReformDef]:
	return _pool.filter(func(reform: ReformDef) -> bool: return not _state.reforms.has(reform.id))


func _reform(reform_id: String) -> ReformDef:
	for reform: ReformDef in _pool:
		if reform.id == reform_id:
			return reform
	return null

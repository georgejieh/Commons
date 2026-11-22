class_name RunShop
extends RefCounted
## One counter between Sets: the state store or the black market (P4.10). Stock is drawn
## on the shop stream by rarity weight from the counter's pool, leaving out what the
## player holds and what the counter has run out of, and bought with coupons at the
## counter's price. A reroll draws new stock for a price that rises with each reroll in
## the visit. Stock is never saved: a save in the shop replays the visit from the Set's
## end, which draws the same stock. A counter with Directive slots also offers Directives
## (ADR 0021), drawn evenly after every Cadre on the stream and redrawn by the same
## reroll; one whose whole family is at the top level is not offered. A counter with
## Campaign offers draws them last of all, evenly from its pool, and the same reroll
## redraws them; a Campaign is refused while the player holds as many as they can. A
## counter with Reform offers draws them after its Campaigns, and the reroll redraws
## them too. A counter with envelope offers draws them after everything else, and the
## reroll redraws them until one is bought (EnvelopeCounter). How many Cadres the player
## can hold is RunReforms.cadre_slots().

enum Reason {
	OK,
	NO_SUCH_SLOT,
	SOLD_OUT,
	TOO_POOR,
	CADRES_FULL,
	LEVELS_MAXED,
	CAMPAIGNS_FULL,
	## An envelope's plot card while the plot is full, and a pick with no envelope open.
	PLOT_FULL,
	NO_ENVELOPE,
}

const SOLD: String = ""
const PERCENT: int = 100

## The counter's Campaigns, drawn after everything else on the shop stream but its
## Reforms and envelopes, which are drawn last.
var campaigns: CampaignCounter
var reforms: ReformCounter
var envelopes: EnvelopeCounter
## Cadre slots lost this visit to a debuff of the Quota just finished (Short Supply,
## ADR 0023). Set before the visit opens; it stacks with rationing.
var short_cut: int = 0
## The visit's first rerolls that cost nothing, from a held Cadre (Back Door, ADR 0032).
var free_rerolls: int = 0

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
	directives: Array[DirectiveDef] = [],
	offered: Array[CampaignDef] = [],
	reformed: Array[ReformDef] = [],
	run: RunParams = null
) -> void:
	_state = state
	_params = params
	_pool = pool
	_ration_cut = ration_cut
	_directives = directives
	campaigns = CampaignCounter.new(state, params, offered)
	reforms = ReformCounter.new(state, params, reformed)
	envelopes = EnvelopeCounter.new(state, params, directives, offered, run)


## Slots this visit offers: fewer while rationing is in force, and fewer under Short
## Supply.
func slot_count() -> int:
	return maxi(_params.slots - (_ration_cut if _state.rationed else 0) - short_cut, 0)


## Starts a visit with fresh Cadres. The Directives, Campaigns, Reforms and envelopes are
## drawn by stock_directives(), campaigns.draw(), reforms.draw() and envelopes.draw().
func open() -> void:
	_rerolls = 0
	_directive_stock.clear()
	campaigns.clear()
	reforms.clear()
	envelopes.clear()
	_restock()


## IDs per slot; SOLD marks a slot already bought.
func stock() -> Array[String]:
	return _stock.duplicate()


## The counter's price for a slot: the item's cost at price_percent, rounded up, then
## under any raise the books made (ADR 0022). Every price on both counters follows them.
func price(slot: int) -> int:
	var cost: int = (_definition(_stock[slot]).cost * _params.price_percent + PERCENT - 1) / PERCENT
	return RunBooks.priced(_state, cost)


## True when the Cadre in a slot is of the top rarity, the kind seldom drawn.
func is_rare(slot: int) -> bool:
	if slot < 0 or slot >= _stock.size() or _stock[slot] == SOLD:
		return false
	return _definition(_stock[slot]).rarity >= ModifierDef.RARE


## How many more of an item this counter will sell this run, or -1 when unlimited.
func left(modifier_id: String) -> int:
	if _params.stock_per_item <= 0:
		return -1
	return maxi(_params.stock_per_item - int(_state.store_sold.get(modifier_id, 0)), 0)


## The next reroll's price: nothing while the visit's free rerolls last, then the price
## every later reroll pays, as if the free ones had been paid for.
func reroll_price() -> int:
	if _rerolls < free_rerolls:
		return 0
	return RunBooks.priced(_state, _params.reroll_base + _rerolls * _params.reroll_step)


## True when a reroll could put something else on the counter: more Cadres to offer
## than slots while the board has room for one, more Directives than their slots, more
## Campaigns than their offers while the player has room for one, or more Reforms open
## than their offers.
func reroll_changes() -> bool:
	var open: int = 0
	for definition: ModifierDef in _pool:
		if not _state.inventory.cadres.has(definition.id) and left(definition.id) != 0:
			open += 1
	if has_room() and open > slot_count():
		return true
	if campaigns.reroll_changes() or reforms.reroll_changes() or envelopes.reroll_changes():
		return true
	return _open_directives().size() > _params.directive_slots


## True while the player's board can take another Cadre.
func has_room() -> bool:
	return _state.inventory.cadres.size() < RunReforms.cadre_slots(_state)


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
	campaigns.draw()
	reforms.draw()
	envelopes.draw()
	return Reason.OK


## Directive IDs per slot; SOLD marks one already issued.
func directive_stock() -> Array[String]:
	return _directive_stock.duplicate()


func directive_price(slot: int) -> int:
	var cost: int = _directive(_directive_stock[slot]).cost
	return RunBooks.priced(_state, (cost * _params.price_percent + PERCENT - 1) / PERCENT)


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
	issue(_state, _directive(_directive_stock[slot]))
	_directive_stock[slot] = SOLD
	return Reason.OK


## Issues a Directive however it was got: each hand type in its family rises a level.
static func issue(state: RunState, directive: DirectiveDef) -> void:
	for type: int in directive.hand_types:
		state.hand_levels.raise(type as Pattern.Type)


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

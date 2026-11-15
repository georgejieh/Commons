class_name EnvelopeCounter
extends RefCounted
## One counter's envelopes (ADR 0021). The offer is drawn last of all on the shop stream,
## evenly from the kinds the counter sells that have something to show, and a reroll
## redraws it until one is bought; once bought, the place is sold for the visit. Buying
## opens the envelope at once: its contents are drawn then, on a stream of their own
## seeded from the run, the visit and the envelope, so they replay exactly from the saved
## commands and shift no later draw on the shop stream. While it is open the player keeps
## one item or none, and nothing else in the shops can be done.

const SOLD: String = ""
const PERCENT: int = 100
## The pick that keeps nothing.
const NOTHING: int = -1
const DEFAULT_RUN: RunParams = preload("res://data/run/default_run.tres")

var _state: RunState
var _params: ShopParams
var _run: RunParams
var _directives: Array[DirectiveDef]
var _campaigns: Array[CampaignDef]
var _stock: Array[String] = []
## The envelope bought this visit, or empty.
var _bought: String = ""
## The envelope open now, and what it shows; null and empty while none is.
var _opened: EnvelopeDef = null
var _items: Array[EnvelopeItem] = []


func _init(
	state: RunState,
	params: ShopParams,
	directives: Array[DirectiveDef],
	campaigns: Array[CampaignDef],
	run: RunParams = null
) -> void:
	_state = state
	_params = params
	_directives = directives
	_campaigns = campaigns
	_run = run if run != null else DEFAULT_RUN


## Envelope IDs per slot; SOLD marks one already bought.
func stock() -> Array[String]:
	return _stock.duplicate()


func price(slot: int) -> int:
	return (definition(_stock[slot]).cost * _params.price_percent + PERCENT - 1) / PERCENT


## How many items an envelope of this kind shows: its own number and the Reforms'.
func choices(envelope_id: String) -> int:
	return definition(envelope_id).choices + RunReforms.extra_envelope_choices(_state)


## True when a reroll could offer another kind.
func reroll_changes() -> bool:
	return _bought.is_empty() and _params.envelope_offers > 0 and _open_kinds().size() > 1


func check(slot: int) -> RunShop.Reason:
	if slot < 0 or slot >= _stock.size():
		return RunShop.Reason.NO_SUCH_SLOT
	if _stock[slot] == SOLD or not _shows_anything(definition(_stock[slot])):
		return RunShop.Reason.SOLD_OUT
	if _state.coupons < price(slot):
		return RunShop.Reason.TOO_POOR
	return RunShop.Reason.OK


## Buys the envelope in slot and opens it: its contents are drawn now.
func buy(slot: int) -> RunShop.Reason:
	var reason: RunShop.Reason = check(slot)
	if reason != RunShop.Reason.OK:
		return reason
	_state.coupons -= price(slot)
	_opened = definition(_stock[slot])
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(_state.run_seed, _key()))
	_items = EnvelopeContents.draw(
		_opened, choices(_opened.id), _state, _directives, _campaigns, stream
	)
	_stock[slot] = SOLD
	_bought = _opened.id
	return RunShop.Reason.OK


## The envelope bought this visit, or empty.
func bought_id() -> String:
	return _bought


func is_open() -> bool:
	return _opened != null


## The open envelope's ID, or empty.
func opened_id() -> String:
	return "" if _opened == null else _opened.id


## Copies of what the open envelope shows, in order.
func items() -> Array[EnvelopeItem]:
	var copies: Array[EnvelopeItem] = []
	for item: EnvelopeItem in _items:
		copies.append(item.copy())
	return copies


## Why the item at index cannot be kept now, or OK. NOTHING can always be picked.
func check_pick(index: int) -> RunShop.Reason:
	if _opened == null:
		return RunShop.Reason.NO_ENVELOPE
	if index == NOTHING:
		return RunShop.Reason.OK
	if index < 0 or index >= _items.size():
		return RunShop.Reason.NO_SUCH_SLOT
	return EnvelopeContents.check(_items[index], _state, _run)


## Keeps the item at index for the seat, or nothing, and closes the envelope.
func pick(index: int, seat: int) -> RunShop.Reason:
	var reason: RunShop.Reason = check_pick(index)
	if reason != RunShop.Reason.OK:
		return reason
	if index != NOTHING:
		EnvelopeContents.take(_items[index], _state, _run, seat, _directives)
	_opened = null
	_items.clear()
	return RunShop.Reason.OK


## A new visit: nothing offered, bought or open.
func clear() -> void:
	_stock.clear()
	_bought = ""
	_opened = null
	_items.clear()


## Draws the visit's offer. The run loop calls it last on the shop stream; a reroll calls
## it again, and once one was bought it keeps the sold place. With a single kind to show
## there is nothing to choose, and the stream is left alone.
func draw() -> void:
	if not _bought.is_empty():
		return
	_stock.clear()
	var open: Array[EnvelopeDef] = _open_kinds()
	var stream: RandomStream = _state.streams.stream(RandomStreams.SHOP)
	while _stock.size() < _params.envelope_offers and not open.is_empty():
		var index: int = 0
		if open.size() > 1:
			index = stream.next_int(0, open.size() - 1)
		_stock.append(open[index].id)
		open.remove_at(index)


func definition(envelope_id: String) -> EnvelopeDef:
	for envelope: EnvelopeDef in _params.envelopes:
		if envelope.id == envelope_id:
			return envelope
	return null


## The kinds this counter sells that have something to show, in data order.
func _open_kinds() -> Array[EnvelopeDef]:
	return _params.envelopes.filter(_shows_anything)


func _shows_anything(envelope: EnvelopeDef) -> bool:
	return envelope != null and EnvelopeContents.has_any(envelope, _state, _directives, _campaigns)


## One key per visit and envelope: a counter sells at most one envelope a visit, and the
## visit is the Set just finished.
func _key() -> String:
	var visit: int = (_state.year - 1) * SetConfig.SETS_PER_YEAR + _state.set_index
	return "envelope:%d:%s" % [visit, _opened.id]

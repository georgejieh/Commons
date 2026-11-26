class_name EnvelopeStall
extends RefCounted
## A shop's envelope (ADR 0021): its offer on the counter as a small sealed envelope or
## parcel whose rules the shared DetailSlip shows, and, once bought, the envelope opened
## over the page in an EnvelopeOverlay. While it is open the screen takes no purchase.
## An envelope still open when the page opens, as after a load, is shown open at once. A
## card for the deck is kept through the page's deck sheet (ADR 0042). Every purchase and
## pick goes through the run controller.

## Coupons changed, so the screen can count them.
signal spent
## The envelope was answered and the overlay is gone: the page shows what was kept.
signal settled

## The offers, one CounterPanel each, for the counter row.
var offers: HBoxContainer = HBoxContainer.new()

var _app: DemoApp
var _market: bool = false
var _shelf: EnvelopeShelf
var _slip: DetailSlip
var _screen_busy: Callable = Callable()
var _host: Control
var _deck: DeckSheet
var _overlay: EnvelopeOverlay = null


func setup(
	app: DemoApp,
	market: bool,
	slip: DetailSlip,
	screen_busy: Callable,
	host: Control,
	deck: DeckSheet
) -> void:
	_app = app
	_market = market
	_shelf = app.controller.store.envelope_shelf(market)
	_slip = slip
	_screen_busy = screen_busy
	_host = host
	_deck = deck
	offers.add_theme_constant_override("separation", 12)


## True while an envelope is open over the page.
func is_busy() -> bool:
	return _overlay != null and is_instance_valid(_overlay)


func overlay() -> EnvelopeOverlay:
	return _overlay if is_busy() else null


## Rebuilds the offer from the counter.
func show_offer() -> void:
	for child: Node in offers.get_children():
		offers.remove_child(child)
		child.queue_free()
	var stock: Array[String] = _shelf.stock()
	for slot: int in stock.size():
		offers.add_child(_offer(slot, stock[slot]))


## The offer's panel in slot, or null.
func panel(slot: int) -> CounterPanel:
	if slot < 0 or slot >= offers.get_child_count():
		return null
	return offers.get_child(slot) as CounterPanel


## Shows an envelope already open, as after a load, laid out at once.
func resume() -> void:
	var open: EnvelopeShelf = _app.controller.store.opened_envelope()
	if open != null and not is_busy():
		_open(open, Rect2(), false)


func _offer(slot: int, envelope_id: String) -> CounterPanel:
	var made: CounterPanel = CounterPanel.new()
	if envelope_id.is_empty():
		if not _shelf.bought_id().is_empty():
			made.set_wrapping(_shelf.wrapping(_shelf.bought_id()))
		made.sold(CounterPanel.Look.ENVELOPE, TranslationServer.translate("envelope.opened"))
		return made
	made.set_wrapping(_shelf.wrapping(envelope_id))
	made.offer(
		CounterPanel.Look.ENVELOPE,
		TranslationServer.translate("envelope.eyebrow"),
		envelope_id,
		_shelf.envelope_name(envelope_id),
		_shelf.envelope_text(envelope_id),
		TranslationServer.translate("store.buy").format({"price": _shelf.price(slot)})
	)
	var coupons: int = _app.controller.state_copy().coupons
	var can: bool = _shelf.can_buy(slot)
	BuyTicket.dress(made.buy, can, _shelf.price(slot), coupons, BuyTicket.Why.EMPTY)
	made.buy.pressed.connect(_buy.bind(slot, made))
	made.described.connect(_describe)
	made.left.connect(_slip.hide_for)
	return made


func _describe(described: CounterPanel) -> void:
	_slip.show_for(described, described.title, described.rule)


## Buys the envelope and opens it over the page, from where its offer stood.
func _buy(slot: int, offered: CounterPanel) -> void:
	if is_busy() or (_screen_busy.is_valid() and _screen_busy.call()):
		return
	var from: Rect2 = offered.get_global_rect()
	if _app.controller.envelope_buy(slot, _market) != RunController.OK:
		show_offer()
		return
	Audio.play(AudioEvents.STORE_BUY)
	spent.emit()
	_slip.hide_slip()
	show_offer()
	_open(_shelf, from, true)


func _open(shelf: EnvelopeShelf, from: Rect2, animate: bool) -> void:
	_overlay = EnvelopeOverlay.new()
	_host.add_child(_overlay)
	_overlay.closed.connect(_on_closed)
	_overlay.use_deck_sheet(_deck)
	_overlay.open(_app.controller, shelf, from, animate)


func _on_closed() -> void:
	_overlay = null
	show_offer()
	settled.emit()

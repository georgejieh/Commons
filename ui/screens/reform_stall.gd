class_name ReformStall
extends RefCounted
## The state store's Reform (ADR 0021): its offer on the counter as a small decree
## poster, and the strip of Reforms in force. Buying is acted out in ink: the decree is
## stamped "Enacted" in red, then flies up and shrinks onto the strip, where its slip is
## pinned and swells. Reduced motion skips to the result. While it plays the screen takes
## no other purchase. Every purchase goes through the run controller.

## Coupons changed, so the screen can count them.
signal spent

const SEAL_WIDTH: float = 112.0
## Seconds the seal sits on the decree, and the decree takes to reach the strip.
const SEAL_HOLD: float = 0.42
const PIN_TIME: float = 0.34
const PIN_SCALE: float = 0.2

## The offers, one CounterPanel each, for the counter row.
var offers: HBoxContainer = HBoxContainer.new()
var strip: ReformStrip = ReformStrip.new()

var _app: DemoApp
var _shelf: ReformShelf = null
var _slip: DetailSlip
var _screen_busy: Callable = Callable()
var _seal: InkSeal = InkSeal.new()
var _busy: bool = false


func setup(app: DemoApp, slip: DetailSlip, screen_busy: Callable, offered: bool) -> void:
	_app = app
	_slip = slip
	_screen_busy = screen_busy
	if offered:
		_shelf = app.controller.store.reform_shelf()
	offers.add_theme_constant_override("separation", 12)
	strip.described.connect(_describe_held)
	strip.left.connect(_slip.hide_for)
	_seal.prepare(TranslationServer.translate("reform.enacted"), ScreenKit.RED, SEAL_WIDTH)
	_seal.top_level = true
	_seal.z_index = 2
	offers.add_child(_seal)


func is_busy() -> bool:
	return _busy


## The seal pressed on an enacted decree, for tests and playtests.
func seal() -> InkSeal:
	return _seal


## Rebuilds the offer and the strip from the run.
func show_offer() -> void:
	strip.show_reforms(_app.controller)
	if _shelf == null:
		return
	for child: Node in offers.get_children():
		if child != _seal:
			offers.remove_child(child)
			child.queue_free()
	var stock: Array[String] = _shelf.stock()
	for slot: int in stock.size():
		offers.add_child(_offer(slot, stock[slot]))


## The offer's panel, or null when there is none.
func panel(slot: int) -> CounterPanel:
	var index: int = 0
	for child: Node in offers.get_children():
		if child is CounterPanel:
			if index == slot:
				return child as CounterPanel
			index += 1
	return null


func _offer(slot: int, reform_id: String) -> CounterPanel:
	var made: CounterPanel = CounterPanel.new()
	if reform_id.is_empty():
		made.sold(CounterPanel.Look.DECREE, TranslationServer.translate("reform.enacted"))
		return made
	var controller: RunController = _app.controller
	made.offer(
		CounterPanel.Look.DECREE,
		TranslationServer.translate("reform.eyebrow"),
		reform_id,
		controller.texts.reform_name(reform_id),
		controller.texts.reform_text(reform_id),
		TranslationServer.translate("store.buy").format({"price": _shelf.price(slot)})
	)
	var coupons: int = controller.run.coupons()
	BuyTicket.dress(made.buy, _shelf.can_buy(slot), _shelf.price(slot), coupons)
	made.buy.pressed.connect(_buy.bind(slot, made))
	made.described.connect(_describe)
	made.left.connect(_slip.hide_for)
	return made


func _describe(described: CounterPanel) -> void:
	_slip.show_for(described, described.title, described.rule)


func _describe_held(tag: Control, reform_id: String) -> void:
	var controller: RunController = _app.controller
	_slip.show_for(
		tag, controller.texts.reform_name(reform_id), controller.texts.reform_text(reform_id), false
	)


## Enacts the offer and acts it out: stamped, then flown up onto the strip.
func _buy(slot: int, offered: CounterPanel) -> void:
	if _busy or (_screen_busy.is_valid() and _screen_busy.call()):
		return
	var held: int = _app.controller.items.held_reforms().size()
	if _app.controller.reform(slot) != RunController.OK:
		show_offer()
		return
	Audio.play(AudioEvents.STORE_BUY)
	spent.emit()
	_slip.hide_for(offered)
	if UiMotion.reduced():
		show_offer()
		strip.pulse(held)
		return
	_busy = true
	offered.buy.disabled = true
	_seal.global_position = offered.global_position + offered.size / 2.0 - _seal.size / 2.0
	_seal.press()
	offered.pivot_offset = offered.size / 2.0
	offered.z_index = 1
	var middle: Vector2 = offered.global_position + offered.size / 2.0
	var to: Vector2 = offered.position + strip.next_center() - middle
	var tween: Tween = offered.create_tween()
	tween.tween_interval(SEAL_HOLD)
	tween.tween_callback(_seal.hide)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(offered, "position", to, PIN_TIME)
	tween.parallel().tween_property(offered, "scale", Vector2.ONE * PIN_SCALE, PIN_TIME)
	tween.tween_callback(_pinned.bind(held))


func _pinned(index: int) -> void:
	_busy = false
	show_offer()
	strip.pulse(index)

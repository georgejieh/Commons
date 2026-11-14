class_name StoreScreen
extends Control
## A shop between Sets (P4.10): Cadres on the counter, bought with coupons, a reroll,
## and what you already hold, pinned on a board. The same screen is the state store and,
## with market set, the black market behind it: the room goes dark, prices are higher,
## the plot can be enlarged, and every purchase adds Resentment, which the screen
## counts. Every purchase goes through the run controller. A purchase is acted out: the
## card is sealed, then flies down to its place on your board.

## Modifier names are long, so they print a step below the title size (the set intro's
## debuff card uses it).
const NAME_SIZE: int = 32
## The reading line wraps at this width, beside the board on its paper chip.
const READING_WIDTH: float = 520.0
const SEAL_WIDTH: float = 250.0
## Seconds the seal sits on a bought card, and the card takes to reach the board.
const SEAL_HOLD: float = 0.42
const PIN_TIME: float = 0.3
const PIN_SCALE: float = 0.3
## The black market is the store after dark, sealed in black ink.
const NIGHT: Color = Color(0.36, 0.34, 0.46)
const NIGHT_SHADE: Color = Color(0.03, 0.02, 0.09, 0.62)
## A card on the counter. The black market's are shorter, to leave room for its
## warning and its tickets.
const CARD: Vector2 = Vector2(360, 470)
const MARKET_CARD: Vector2 = Vector2(360, 390)
const MARKET_INK: Color = Color("1e1a16")

## True for the black market. Set on the scene.
@export var market: bool = false

var _app: DemoApp
var _counter: HBoxContainer = HBoxContainer.new()
var _coupons: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _board: NoticeBoard = NoticeBoard.new()
var _seal: InkSeal = InkSeal.new()
## True while a purchase is being acted out: the counter takes no second one.
var _busy: bool = false
var _desk: ShopDesk
## The black market's Resentment count and plot upgrades; the state store has neither.
var _resentment: Label = null
var _shown_resentment: float = 0.0
var _upgrades: HBoxContainer = null
## The name and rules of the Cadre under the pointer or focus, for keyboard and gamepad.
var _reading: Label = ScreenKit.label("", 20)
var _reroll: Button = ScreenKit.button("", CommonsTheme.GHOST)
var _shown_coupons: float = 0.0


func open(app: DemoApp) -> void:
	_app = app
	_desk = app.controller.desk(market)
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.store)
	var place: String = "market" if market else "store"
	var heading: Control = ScreenKit.header(tr(place + ".eyebrow"), tr(place + ".title"))
	if market:
		# The backdrop is the page's first child.
		(get_child(0) as Control).modulate = NIGHT
		# The page's shade is its second child: deepened to night.
		(get_child(1) as ColorRect).color = NIGHT_SHADE
	var balance: VBoxContainer = VBoxContainer.new()
	balance.add_child(ScreenKit.eyebrow(tr("store.balance")))
	_coupons.add_theme_color_override("font_color", ScreenKit.COUPON)
	_coupons.autowrap_mode = TextServer.AUTOWRAP_OFF
	# The chip shrinks to its content, so a wrapping label needs a set width.
	_reading.custom_minimum_size = Vector2(READING_WIDTH, 0)
	_board.setup(app.controller.cadre_slots())
	balance.add_child(_coupons)
	balance.size_flags_vertical = Control.SIZE_SHRINK_END
	var top: Array[Control] = [heading, balance]
	if market:
		top.append(_resentment_box())
	column.add_child(ScreenKit.row(top, 64))
	if market:
		column.add_child(_warning())
	_counter.add_theme_constant_override("separation", 28)
	column.add_child(_counter)
	_reroll.pressed.connect(_on_reroll)
	var leave: Button = ScreenKit.button(
		tr("market.back" if market else "store.leave"), CommonsTheme.PRIMARY
	)
	if market:
		leave.pressed.connect(app.back)
		_upgrades = HBoxContainer.new()
		_upgrades.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
		column.add_child(ScreenKit.row([leave, _reroll, _upgrades]))
	else:
		leave.pressed.connect(_leave)
		var door: Button = ScreenKit.button(tr("market.open"), CommonsTheme.GHOST)
		door.pressed.connect(func() -> void: app.show_screen("black_market"))
		column.add_child(ScreenKit.row([leave, _reroll, door]))
		if app.controller.is_rationed():
			column.add_child(_rationing_note(app.controller))
	# A paper chip, so the line reads over the mural.
	var chip: VBoxContainer = ScreenKit.card(Vector2(0, 0))
	chip.add_child(ScreenKit.eyebrow(tr("store.shelf")))
	chip.add_child(ScreenKit.row([_board, _reading], 24))
	var chip_panel: Control = ScreenKit.card_panel(chip)
	chip_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(chip_panel)
	var word: String = tr("market.paid" if market else "store.approved")
	_seal.prepare(word, MARKET_INK if market else ScreenKit.RED, SEAL_WIDTH)
	add_child(_seal)
	_shown_coupons = app.controller.state_copy().coupons
	_shown_resentment = app.controller.state_copy().resentment
	_refresh()
	ScreenKit.reveal(column)
	leave.grab_focus()


func _refresh() -> void:
	var controller: RunController = _app.controller
	var state: RunState = controller.state_copy()
	UiMotion.count(_coupons, _shown_coupons, state.coupons, _coupon_text)
	_shown_coupons = state.coupons
	_read("")
	for child: Node in _counter.get_children():
		_counter.remove_child(child)
		child.queue_free()
	var stock: Array[String] = _desk.stock()
	for slot: int in stock.size():
		_counter.add_child(_item(slot, stock[slot]))
	if stock.is_empty():
		_counter.add_child(ScreenKit.styled(tr("market.empty"), CommonsTheme.HEADLINE))
	_reroll.text = tr("store.reroll").format({"price": _desk.reroll_price()})
	_reroll.disabled = not _desk.can_reroll()
	if market:
		UiMotion.count(_resentment, _shown_resentment, state.resentment, _resentment_text)
		if state.resentment > _shown_resentment:
			UiMotion.pulse(_resentment)
		_shown_resentment = state.resentment
		_show_upgrades()
	_board.show_cadres(controller)


func _item(slot: int, cadre_id: String) -> Control:
	var card: VBoxContainer = ScreenKit.card(MARKET_CARD if market else CARD)
	if cadre_id.is_empty():
		var sold: Label = ScreenKit.styled(tr("store.sold"), CommonsTheme.HEADLINE)
		sold.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(sold)
		UiMotion.stamp(sold)
		return ScreenKit.card_panel(card)
	var controller: RunController = _app.controller
	var tip: String = ScreenKit.cadre_tip(controller, cadre_id)
	# The card face is the art alone; its name and rules are in the tooltip. A Cadre
	# with no art yet shows its name on the card stock.
	if ScreenKit.ART.cadre(cadre_id) != null:
		var picture: TextureRect = ScreenKit.cover(ScreenKit.cadre_art(cadre_id))
		picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
	else:
		var name: Label = ScreenKit.styled(tr("modifier.%s.name" % cadre_id), CommonsTheme.TITLE)
		name.size_flags_vertical = Control.SIZE_EXPAND_FILL
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.custom_minimum_size = Vector2(300, 0)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name)
	var buy: Button = ScreenKit.button(
		tr("store.buy").format({"price": _desk.price(slot)}), CommonsTheme.COUPON
	)
	buy.size_flags_horizontal = Control.SIZE_FILL
	buy.disabled = not _desk.can_buy(slot)
	buy.tooltip_text = tip
	buy.focus_entered.connect(_read.bind(tip))
	card.add_child(buy)
	var panel: Control = ScreenKit.card_panel(card)
	buy.pressed.connect(_buy.bind(slot, panel))
	panel.tooltip_text = tip
	panel.mouse_entered.connect(_read.bind(tip))
	UiMotion.hoverable(panel)
	return panel


## Buys the Cadre in a slot and acts it out: the coupons roll down, the card is sealed,
## then it shrinks away to its place on the board. Reduced motion skips to the result.
func _buy(slot: int, panel: Control) -> void:
	if _busy:
		return
	var controller: RunController = _app.controller
	var held: int = controller.state_copy().inventory.cadres.size()
	if market:
		controller.market_buy(slot)
	else:
		controller.buy(slot)
	var state: RunState = controller.state_copy()
	if state.inventory.cadres.size() == held:
		_refresh()
		return
	Audio.play(AudioEvents.STORE_BUY)
	if UiMotion.reduced():
		_refresh()
		return
	_busy = true
	UiMotion.count(_coupons, _shown_coupons, state.coupons, _coupon_text)
	_shown_coupons = state.coupons
	UiMotion.pulse(_coupons)
	var middle: Vector2 = panel.global_position + panel.size / 2.0
	_seal.position = middle - global_position - _seal.size / 2.0
	move_child(_seal, -1)
	_seal.press()
	panel.z_index = 1
	var to: Vector2 = panel.position + _board.slot_center(held) - middle
	var tween: Tween = create_tween()
	tween.tween_interval(SEAL_HOLD)
	tween.tween_callback(_seal.hide)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position", to, PIN_TIME)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE * PIN_SCALE, PIN_TIME)
	tween.tween_callback(_pinned.bind(held))


## The bought card has reached the board: the counter shows the gap, the board the card.
func _pinned(slot: int) -> void:
	_busy = false
	_refresh()
	_board.pulse_slot(slot)


## True while a purchase is being acted out, for tests.
func is_buying() -> bool:
	return _busy


## Shows a Cadre's name and rules on the reading line; an empty line takes no space.
func _read(tip: String) -> void:
	_reading.text = tip
	_reading.visible = not tip.is_empty()


## The black market's warning: what every purchase there costs beyond coupons.
func _warning() -> Control:
	var note: KeywordText = KeywordText.new()
	note.add_theme_font_size_override("normal_font_size", 24)
	note.add_theme_color_override("default_color", ScreenKit.STYLE.paper_bright)
	note.custom_minimum_size = Vector2(READING_WIDTH * 2.0, 0)
	note.set_rule(tr("market.warning").format({"rise": _app.controller.purchase_resentment()}))
	return note


func _resentment_box() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_child(ScreenKit.eyebrow(tr("keyword.resentment.name")))
	_resentment = ScreenKit.styled("", CommonsTheme.TITLE)
	_resentment.add_theme_color_override("font_color", ScreenKit.RED)
	_resentment.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(_resentment)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	return box


func _resentment_text(value: float) -> String:
	return str(roundi(value))


## The private-plot upgrades on sale: one ticket each, off once bought out or too dear.
func _show_upgrades() -> void:
	for child: Node in _upgrades.get_children():
		_upgrades.remove_child(child)
		child.queue_free()
	for kind: String in _desk.upgrade_kinds():
		var text: String = tr("market.upgrade." + kind).format({"price": _desk.upgrade_price(kind)})
		if _desk.upgrades_left(kind) <= 0:
			text = tr("market.upgrade.%s.out" % kind)
		var ticket: Button = ScreenKit.button(text, CommonsTheme.COUPON)
		ticket.disabled = not _desk.can_upgrade(kind)
		ticket.tooltip_text = Keywords.wrapped(tr("market.upgrade.%s.tip" % kind))
		ticket.pressed.connect(_upgrade.bind(kind))
		_upgrades.add_child(ticket)


func _upgrade(kind: String) -> void:
	if _busy:
		return
	_app.controller.upgrade(kind)
	Audio.play(AudioEvents.STORE_BUY)
	_refresh()


func _on_reroll() -> void:
	if market:
		_app.controller.market_reroll()
	else:
		_app.controller.reroll()
	_refresh()
	var fresh: Array[Control] = []
	for child: Node in _counter.get_children():
		fresh.append(child as Control)
	UiMotion.enter(fresh)


## Leaves the store for the next Quota.
func _leave() -> void:
	_app.controller.leave_store()
	_app.show_screen("set_intro", true)


func _coupon_text(value: float) -> String:
	return Strings.count("store.coupons", roundi(value))


## Why the counter is short while rationing holds.
func _rationing_note(controller: RunController) -> Label:
	var slots: int = controller.store_stock().size()
	var text: String = Strings.count("store.rationed", slots).format(
		{"below": controller.rationing_lifts_below()}
	)
	var note: Label = ScreenKit.label(text, 22)
	note.add_theme_color_override("font_color", ScreenKit.RED)
	return note

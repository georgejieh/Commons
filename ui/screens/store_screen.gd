class_name StoreScreen
extends Control
## The state store between Sets: three Cadres on the counter, bought with coupons, a
## reroll, and what you already hold, pinned on a board. Every purchase goes through
## the run controller. A purchase is acted out: the card is sealed "approved", then
## flies down to its place on your board.

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

var _app: DemoApp
var _counter: HBoxContainer = HBoxContainer.new()
var _coupons: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _board: NoticeBoard = NoticeBoard.new()
var _seal: InkSeal = InkSeal.new()
## True while a purchase is being acted out: the counter takes no second one.
var _busy: bool = false
## The name and rules of the Cadre under the pointer or focus, for keyboard and gamepad.
var _reading: Label = ScreenKit.label("", 20)
var _reroll: Button = ScreenKit.button("", CommonsTheme.GHOST)
var _shown_coupons: float = 0.0


func open(app: DemoApp) -> void:
	_app = app
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.store)
	var heading: Control = ScreenKit.header(tr("store.eyebrow"), tr("store.title"))
	var balance: VBoxContainer = VBoxContainer.new()
	balance.add_child(ScreenKit.eyebrow(tr("store.balance")))
	_coupons.add_theme_color_override("font_color", ScreenKit.COUPON)
	_coupons.autowrap_mode = TextServer.AUTOWRAP_OFF
	# The chip shrinks to its content, so a wrapping label needs a set width.
	_reading.custom_minimum_size = Vector2(READING_WIDTH, 0)
	_board.setup(app.controller.cadre_slots())
	balance.add_child(_coupons)
	balance.size_flags_vertical = Control.SIZE_SHRINK_END
	column.add_child(ScreenKit.row([heading, balance], 64))
	_counter.add_theme_constant_override("separation", 28)
	column.add_child(_counter)
	_reroll.pressed.connect(_on_reroll)
	var leave: Button = ScreenKit.button(tr("store.leave"), CommonsTheme.PRIMARY)
	leave.pressed.connect(
		func() -> void:
			app.controller.leave_store()
			app.show_screen("set_intro", true)
	)
	var market: Button = ScreenKit.button(tr("market.open"), CommonsTheme.GHOST)
	market.pressed.connect(func() -> void: app.show_screen("black_market"))
	column.add_child(ScreenKit.row([leave, _reroll, market]))
	if app.controller.is_rationed():
		column.add_child(_rationing_note(app.controller))
	# A paper chip, so the line reads over the mural.
	var chip: VBoxContainer = ScreenKit.card(Vector2(0, 0))
	chip.add_child(ScreenKit.eyebrow(tr("store.shelf")))
	chip.add_child(ScreenKit.row([_board, _reading], 24))
	var chip_panel: Control = ScreenKit.card_panel(chip)
	chip_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(chip_panel)
	_seal.prepare(tr("store.approved"), ScreenKit.RED, SEAL_WIDTH)
	add_child(_seal)
	_shown_coupons = app.controller.state_copy().coupons
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
	var stock: Array[String] = controller.store_stock()
	for slot: int in stock.size():
		_counter.add_child(_item(slot, stock[slot]))
	_reroll.text = tr("store.reroll").format({"price": controller.reroll_price()})
	_reroll.disabled = not controller.can_reroll()
	_board.show_cadres(controller)


func _item(slot: int, cadre_id: String) -> Control:
	var card: VBoxContainer = ScreenKit.card(Vector2(360, 470))
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
	# The card face is the art alone; its name and rules are in the tooltip.
	var picture: TextureRect = ScreenKit.cover(ScreenKit.cadre_art(cadre_id))
	picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(picture)
	var buy: Button = ScreenKit.button(
		tr("store.buy").format({"price": controller.store_price(slot)}), CommonsTheme.COUPON
	)
	buy.size_flags_horizontal = Control.SIZE_FILL
	buy.disabled = not controller.can_buy(slot)
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


func _on_reroll() -> void:
	_app.controller.reroll()
	_refresh()
	var fresh: Array[Control] = []
	for child: Node in _counter.get_children():
		fresh.append(child as Control)
	UiMotion.enter(fresh)


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

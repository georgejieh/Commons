class_name StoreScreen
extends Control
## The state store between Sets: three Cadres on the counter, bought with coupons, a
## reroll, and what you already hold. Every purchase goes through the run controller.

## Cadre names are long, so they print a step below the title size.
const NAME_SIZE: int = 32

var _app: DemoApp
var _counter: HBoxContainer = HBoxContainer.new()
var _coupons: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _owned: Label = ScreenKit.styled("", CommonsTheme.CAPTION)
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
	_owned.add_theme_font_size_override("font_size", 22)
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
	column.add_child(ScreenKit.row([leave, _reroll]))
	# A paper chip, so the line reads over the mural.
	var chip: VBoxContainer = ScreenKit.card(Vector2(0, 0))
	chip.add_child(_owned)
	var chip_panel: Control = ScreenKit.card_panel(chip)
	chip_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(chip_panel)
	_shown_coupons = app.controller.state_copy().coupons
	_refresh()
	ScreenKit.reveal(column)
	leave.grab_focus()


func _refresh() -> void:
	var controller: RunController = _app.controller
	var state: RunState = controller.state_copy()
	UiMotion.count(_coupons, _shown_coupons, state.coupons, _coupon_text)
	_shown_coupons = state.coupons
	for child: Node in _counter.get_children():
		_counter.remove_child(child)
		child.queue_free()
	var stock: Array[String] = controller.store_stock()
	for slot: int in stock.size():
		_counter.add_child(_item(slot, stock[slot]))
	_reroll.text = tr("store.reroll").format({"price": controller.reroll_price()})
	_reroll.disabled = not controller.can_reroll()
	var names: PackedStringArray = []
	for cadre_id: String in state.inventory.cadres:
		names.append(tr("modifier.%s.name" % cadre_id))
	_owned.text = tr("store.owned").format(
		{"names": ", ".join(names) if not names.is_empty() else tr("store.none")}
	)


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
	var picture: TextureRect = ScreenKit.cover(ScreenKit.ART.cadre(cadre_id))
	picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	picture.custom_minimum_size = Vector2(0, 190)
	card.add_child(picture)
	card.add_child(ScreenKit.eyebrow(tr("store.cadre")))
	var name: Label = ScreenKit.styled(tr("modifier.%s.name" % cadre_id), CommonsTheme.TITLE)
	name.add_theme_font_size_override("font_size", NAME_SIZE)
	card.add_child(name)
	var rules: Label = ScreenKit.label(controller.modifier_text(cadre_id), 20)
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(rules)
	var buy: Button = ScreenKit.button(
		tr("store.buy").format({"price": controller.store_price(slot)}), CommonsTheme.COUPON
	)
	buy.size_flags_horizontal = Control.SIZE_FILL
	buy.disabled = not controller.can_buy(slot)
	buy.pressed.connect(
		func() -> void:
			controller.buy(slot)
			_refresh()
	)
	card.add_child(buy)
	var panel: Control = ScreenKit.card_panel(card)
	UiMotion.hoverable(panel)
	return panel


func _on_reroll() -> void:
	_app.controller.reroll()
	_refresh()
	var fresh: Array[Control] = []
	for child: Node in _counter.get_children():
		fresh.append(child as Control)
	UiMotion.enter(fresh)


func _coupon_text(value: float) -> String:
	return tr("store.coupons").format({"count": roundi(value)})

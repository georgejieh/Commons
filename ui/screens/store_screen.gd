class_name StoreScreen
extends Control
## The state store between Sets: three Cadres on the counter, bought with coupons, a
## reroll, and your notice board. Every purchase goes through the run controller.

var _app: DemoApp
var _counter: HBoxContainer = HBoxContainer.new()
var _coupons: Label = ScreenKit.label("", 30, ScreenKit.COUPON)
var _owned: Label = ScreenKit.label("", 22)
var _reroll: Button = ScreenKit.button("")


func open(app: DemoApp) -> void:
	_app = app
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.label(tr("store.title"), 72, ScreenKit.RED))
	column.add_child(_coupons)
	_counter.add_theme_constant_override("separation", 32)
	column.add_child(_counter)
	_reroll.pressed.connect(_on_reroll)
	column.add_child(_reroll)
	column.add_child(_owned)
	var leave: Button = ScreenKit.button(tr("store.leave"), ScreenKit.RED)
	leave.pressed.connect(
		func() -> void:
			app.controller.leave_store()
			app.show_screen("set_intro", true)
	)
	column.add_child(leave)
	_refresh()
	leave.grab_focus()


func _refresh() -> void:
	var controller: RunController = _app.controller
	var state: RunState = controller.state_copy()
	_coupons.text = tr("store.coupons").format({"count": state.coupons})
	for child: Node in _counter.get_children():
		_counter.remove_child(child)
		child.queue_free()
	var stock: Array[String] = controller.store_stock()
	for slot: int in stock.size():
		_counter.add_child(_item(slot, stock[slot]))
	_reroll.text = tr("store.reroll").format({"price": controller.reroll_price()})
	var names: PackedStringArray = []
	for cadre_id: String in state.inventory.cadres:
		names.append(tr("modifier.%s.name" % cadre_id))
	_owned.text = tr("store.owned").format(
		{"names": ", ".join(names) if not names.is_empty() else tr("store.none")}
	)


func _item(slot: int, cadre_id: String) -> Control:
	var card: VBoxContainer = ScreenKit.card(Vector2(360, 380))
	if cadre_id.is_empty():
		card.add_child(ScreenKit.label(tr("store.sold"), 30))
		return ScreenKit.card_panel(card)
	var controller: RunController = _app.controller
	card.add_child(ScreenKit.label(tr("modifier.%s.name" % cadre_id), 30, ScreenKit.RED))
	card.add_child(ScreenKit.label(controller.modifier_text(cadre_id), 22))
	var buy: Button = ScreenKit.button(
		tr("store.buy").format({"price": controller.store_price(slot)}), ScreenKit.COUPON
	)
	buy.disabled = not controller.can_buy(slot)
	buy.pressed.connect(
		func() -> void:
			controller.buy(slot)
			_refresh()
	)
	card.add_child(buy)
	return ScreenKit.card_panel(card)


func _on_reroll() -> void:
	_app.controller.reroll()
	_refresh()

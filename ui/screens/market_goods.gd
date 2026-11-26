class_name MarketGoods
extends RefCounted
## What only the black market sells besides Cadres and Campaigns (P4.8, P4.10): cards for
## the private plot, on a paper sheet beside the Cadres with how full the plot is, and
## the plot upgrades as tickets in the button row. Every purchase is private, so it goes
## through the screen's buy, with the action's name and slot for the arrival's gate, which
## adds the sound and refreshes the page.

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")

## The plot cards' sheet, for the main row, and the upgrade tickets, for the button row.
var sheet: VBoxContainer = ScreenKit.card(Vector2.ZERO)
var upgrades: HBoxContainer = HBoxContainer.new()

var _controller: RunController
var _desk: ShopDesk
var _buy: Callable
var _card_buttons: Array[Button] = []


func setup(controller: RunController, desk: ShopDesk, buy: Callable) -> void:
	_controller = controller
	_desk = desk
	_buy = buy
	sheet.add_theme_constant_override("separation", 10)
	upgrades.add_theme_constant_override("separation", ScreenKit.STYLE.gap)


## The sheet's outer panel, for the main row.
func panel() -> Control:
	return ScreenKit.card_panel(sheet)


func refresh() -> void:
	_show_upgrades()
	_show_stall()


## The private-plot upgrades on sale: one ticket each, off once bought out or too dear.
func _show_upgrades() -> void:
	for child: Node in upgrades.get_children():
		upgrades.remove_child(child)
		child.queue_free()
	for kind: String in _desk.upgrade_kinds():
		var text: String = _tr("market.upgrade." + kind).format(
			{"price": _desk.upgrade_price(kind)}
		)
		if _desk.upgrades_left(kind) <= 0:
			text = _tr("market.upgrade.%s.out" % kind)
		var ticket: Button = ScreenKit.button(text, CommonsTheme.COUPON)
		ticket.disabled = not _desk.can_upgrade(kind)
		BuyTicket.readable(ticket)
		ticket.tooltip_text = Keywords.wrapped(_tr("market.upgrade.%s.tip" % kind))
		ticket.pressed.connect(_buy.bind(_controller.upgrade.bind(kind), "upgrade"))
		upgrades.add_child(ticket)


## The cards for the private plot on offer: each as a card over its Buy button.
func _show_stall() -> void:
	for child: Node in sheet.get_children():
		sheet.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	var head: Label = ScreenKit.eyebrow(
		_tr("market.plot").format({"held": _desk.plot_size(), "room": _desk.plot_capacity()})
	)
	sheet.add_child(head)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	# In the tree first: a card view is only ready to show a card once it is in it.
	sheet.add_child(cards)
	for slot: int in _desk.plot_card_count():
		var card: CardInstance = _desk.plot_card(slot)
		var item: VBoxContainer = VBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		cards.add_child(item)
		var view: CardView = CARD_SCENE.instantiate()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A card keeps a card's proportions, as the table draws it: the Buy ticket under it
		# may be wider, and the card stands centred over it, never stretched to its width.
		view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		item.add_child(view)
		view.bind(card)
		view.visible = true
		view.modulate.a = 1.0 if card != null else 0.0
		var buy: Button = ScreenKit.button(_tr("store.sold"), CommonsTheme.COUPON)
		buy.custom_minimum_size = Vector2(view.custom_minimum_size.x, 0)
		buy.add_theme_font_size_override("font_size", TextSize.px(CounterPanel.BUY_SIZE))
		buy.disabled = true
		BuyTicket.readable(buy)
		if card != null:
			var can: bool = _desk.can_buy_plot_card(slot)
			BuyTicket.dress(buy, can, _desk.plot_card_price(slot), _coupons())
		buy.tooltip_text = Keywords.wrapped(_tr("market.plot.tip"))
		buy.pressed.connect(_buy.bind(_controller.plot_card.bind(slot), "plot_card", slot))
		item.add_child(buy)
		_card_buttons.append(buy)


## The card shown in a slot of the stall, or null, for tests.
func card_view(slot: int) -> CardView:
	if slot >= _card_buttons.size():
		return null
	return _card_buttons[slot].get_parent().get_child(0) as CardView


## The Buy button under a plot card, or null.
func card_button(slot: int) -> Button:
	return _card_buttons[slot] if slot < _card_buttons.size() else null


func _coupons() -> int:
	return _controller.run.coupons()


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)

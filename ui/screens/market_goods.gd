class_name MarketGoods
extends RefCounted
## What only the black market sells besides Cadres and Campaigns: cards for the private
## plot, on a paper sheet beside the Cadres with how full the plot is, each explained in
## the page's slip, and the plot upgrades as tickets in the button row. Every purchase
## passes the arrival's gate by its action's name and slot, sounds, and is reported by
## spent, so the page shows what it changed.

## A card or an upgrade was bought.
signal spent

## Between a plot card and its ticket.
const ITEM_GAP: int = 8

## The plot cards' sheet, for the main row.
var sheet: VBoxContainer = ScreenKit.card(Vector2.ZERO)
## The upgrade tickets, for the button row.
var upgrades: HBoxContainer = HBoxContainer.new()

var _shop: StallContext
var _items: Array[BuyItem] = []


## Gives the page its shared stall context; call once, before the first refresh.
func setup(shop: StallContext) -> void:
	_shop = shop
	sheet.add_theme_constant_override("separation", 10)
	upgrades.add_theme_constant_override("separation", ScreenKit.STYLE.gap)


## The sheet's outer panel, for the main row.
func panel() -> Control:
	return ScreenKit.card_panel(sheet)


## Draws the upgrade tickets and the plot cards again from the desk, after anything changed.
func refresh() -> void:
	_show_upgrades()
	_show_stall()


## The card shown in a slot of the stall, or null, for tests.
func card_view(slot: int) -> CardView:
	return _items[slot].view if slot < _items.size() else null


## The Buy button under a plot card, or null.
func card_button(slot: int) -> Button:
	return _items[slot].buy if slot < _items.size() else null


## The private-plot upgrades on sale: one ticket each, off once bought out or too dear.
func _show_upgrades() -> void:
	ScreenKit.clear(upgrades)
	var desk: ShopDesk = _shop.desk
	for kind: String in desk.upgrade_kinds():
		var text: String = tr("market.upgrade." + kind).format({"price": desk.upgrade_price(kind)})
		if desk.upgrades_left(kind) <= 0:
			text = tr("market.upgrade.%s.out" % kind)
		var ticket: Button = ScreenKit.button(text, CommonsTheme.COUPON)
		ticket.disabled = not desk.can_upgrade(kind)
		BuyTicket.readable(ticket)
		_shop.slip.follow(ticket, "", tr("market.upgrade.%s.tip" % kind))
		ticket.pressed.connect(_buy.bind(_shop.controller.upgrade.bind(kind), "upgrade"))
		upgrades.add_child(ticket)


## The cards for the private plot on offer: each as a card over its Buy button.
func _show_stall() -> void:
	ScreenKit.clear(sheet)
	_items.clear()
	var desk: ShopDesk = _shop.desk
	var head: Label = ScreenKit.eyebrow(
		tr("market.plot").format({"held": desk.plot_size(), "room": desk.plot_capacity()})
	)
	sheet.add_child(head)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	# In the tree first: a card view is only ready to show a card once it is in it.
	sheet.add_child(cards)
	var rule: String = tr("market.plot.tip")
	for slot: int in desk.plot_card_count():
		var card: CardInstance = desk.plot_card(slot)
		var item: BuyItem = BuyItem.new(cards, card, 1.0, ITEM_GAP)
		if card != null:
			var can: bool = desk.can_buy_plot_card(slot)
			BuyTicket.dress(
				item.buy, can, desk.plot_card_price(slot), _shop.controller.run.coupons()
			)
		var title: String = "" if card == null else ExchangeChoice.card_text(card)
		_shop.slip.follow(item.buy, title, rule)
		var act: Callable = _shop.controller.plot_card.bind(slot)
		item.buy.pressed.connect(_buy.bind(act, "plot_card", slot))
		_items.append(item)


## Buys by act once nothing is being acted out and the arrival allows it.
func _buy(act: Callable, action: String, slot: int = -1) -> void:
	if _shop.busy.call() or not _shop.app.arrival.attempt(action, slot):
		return
	act.call()
	Audio.play(AudioEvents.STORE_BUY)
	spent.emit()

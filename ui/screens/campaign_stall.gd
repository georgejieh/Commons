class_name CampaignStall
extends RefCounted
## A shop's Campaign (ADR 0021): the counter's offer as a compact leaflet "On the
## counter", whose rules the shared DetailSlip shows, and the player's tray of held
## Campaigns, which sits on the board beside the Cadres. Buying flies the leaflet into the
## tray. In a shop only Grain Loan can be used: armed from the tray, then confirmed with
## Use, while the slip states what Use will do. Every purchase and use goes through the
## controller.

## Emitted when coupons changed, so the screen can count them.
signal spent

const FLY_TIME: float = 0.34
const FLY_SCALE: float = 0.9

var tray: CampaignTray = CampaignTray.new()
## The offers, one CounterPanel each, for the counter row.
var offers: HBoxContainer = HBoxContainer.new()

var _app: App
var _market: bool = false
var _shelf: CampaignShelf
var _slip: DetailSlip
var _screen_busy: Callable
var _flier: CampaignLeaflet = CampaignLeaflet.new()
var _busy: bool = false


func setup(shop: StallContext) -> void:
	_app = shop.app
	_market = shop.market
	_shelf = shop.controller.store.campaign_shelf(shop.market)
	_screen_busy = shop.busy
	_slip = shop.slip
	offers.add_theme_constant_override("separation", 12)
	tray.side_buttons = true
	tray.compact = true
	tray.setup(shop.controller)
	tray.changed.connect(_show_prompt)
	tray.used.connect(_on_used)
	_flier.top_level = true
	_flier.z_index = ScreenKit.LAYER_OVER
	_flier.visible = false
	_flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(_flier)


func is_busy() -> bool:
	return _busy


## Rebuilds the offer and the tray from the counter.
func show_offer() -> void:
	ScreenKit.clear(offers)
	var stock: Array[String] = _shelf.stock()
	for slot: int in stock.size():
		offers.add_child(_offer(slot, stock[slot]))
	tray.enabled = not _busy
	tray.refresh()
	_show_prompt()


## The offer's panel in slot, or null.
func panel(slot: int) -> CounterPanel:
	if slot < 0 or slot >= offers.get_child_count():
		return null
	return offers.get_child(slot) as CounterPanel


func _offer(slot: int, campaign_id: String) -> CounterPanel:
	var made: CounterPanel = CounterPanel.new()
	if campaign_id.is_empty():
		made.sold(CounterPanel.Look.LEAFLET, tr("store.sold"))
		return made
	var controller: RunController = _app.controller
	var private: bool = controller.items.is_private_campaign(campaign_id)
	made.set_private(private)
	made.offer(
		CounterPanel.Look.LEAFLET,
		tr("campaign.eyebrow.private" if private else "campaign.eyebrow.collective"),
		campaign_id,
		controller.texts.campaign_name(campaign_id),
		controller.texts.campaign_text(campaign_id),
		tr("store.buy").format({"price": _shelf.price(slot)})
	)
	var coupons: int = controller.run.coupons()
	var why: BuyTicket.Why = BuyTicket.Why.FULL
	if _shelf.is_sold_back(slot):
		why = BuyTicket.Why.SOLD_BACK
	BuyTicket.dress(made.buy, _shelf.can_buy(slot), _shelf.price(slot), coupons, why)
	if _shelf.is_full():
		made.rule += "\n\n" + tr("campaign.full")
	made.buy.pressed.connect(_buy.bind(slot, made))
	made.described.connect(_describe)
	made.left.connect(_slip.hide_for)
	return made


func _describe(described: CounterPanel) -> void:
	if tray.armed_slot() < 0:
		_slip.show_for(described, described.title, described.rule)


## Buys the offer and flies its leaflet into the tray's next place.
func _buy(slot: int, offered: CounterPanel) -> void:
	if _busy or _screen_busy.call():
		return
	var held: int = _app.controller.items.held_campaigns().size()
	var from: Vector2 = offered.global_position
	var shown: String = offered.shown_name()
	var private: bool = offered.is_private()
	var campaign_id: String = offered.item_id
	if _app.controller.campaign_buy(slot, _market) != RunController.OK:
		show_offer()
		return
	Audio.play(AudioEvents.STORE_BUY)
	spent.emit()
	_slip.hide_for(offered)
	if UiMotion.reduced():
		show_offer()
		return
	_busy = true
	tray.refresh()
	_flier.show_campaign(held, campaign_id, shown, "", private)
	_flier.set_compact(true)
	_flier.size = CampaignLeaflet.leaf_size(true)
	_flier.global_position = from
	_flier.scale = Vector2.ONE
	_flier.visible = true
	offered.modulate.a = 0.0
	tray.leaflet(held).modulate.a = 0.0
	var to: Vector2 = tray.slot_center(held) - _flier.size / 2.0
	var tween: Tween = _flier.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_flier, "global_position", to, FLY_TIME)
	tween.parallel().tween_property(_flier, "scale", Vector2.ONE * FLY_SCALE, FLY_TIME)
	tween.tween_callback(_landed.bind(held))


func _landed(slot: int) -> void:
	_busy = false
	_flier.visible = false
	show_offer()
	if slot < tray.campaign_count():
		UiMotion.pulse(tray.leaflet(slot))


## A Grain Loan used here pays at once; a loan that starves the village ends the run.
func _on_used(_slot: int, _campaign_id: String) -> void:
	spent.emit()
	show_offer()
	if _app.controller.awaiting() == RunController.AWAIT_RUN_OVER:
		_app.show_screen(ScreenId.SET_SUMMARY, true)


## While a leaflet is armed, the slip says what Use will do, over the tray.
func _show_prompt() -> void:
	var asked: String = tray.prompt()
	if asked.is_empty():
		_slip.hide_for(tray)
		return
	var held: String = _app.controller.items.held_campaigns()[tray.armed_slot()]
	_slip.show_for(tray, _app.controller.texts.campaign_name(held), asked)

class_name CampaignStall
extends RefCounted
## A shop's Campaign (ADR 0021): the counter's one offer as a leaflet with its rules and
## price, set beside the Directives at the state store and under the plot cards at the
## black market, and the player's two-slot tray on the shelf with the Cadre board. Buying
## flies the leaflet into the tray. In a shop only Grain Loan can be used: armed from
## the tray, then confirmed with Use. Every purchase and use goes through the controller.

## Emitted when coupons changed, so the screen can count them.
signal spent

const RULE_WIDTH: float = 236.0
const RULE_SIZE: int = 16
const FLY_TIME: float = 0.34
const FLY_SCALE: float = 0.9

var tray: CampaignTray = CampaignTray.new()

var _app: DemoApp
var _market: bool = false
var _shelf: CampaignShelf
var _screen_busy: Callable = Callable()
var _offers: VBoxContainer = VBoxContainer.new()
var _prompt: Label = ScreenKit.label("", RULE_SIZE)
var _flier: CampaignLeaflet = CampaignLeaflet.new()
var _busy: bool = false


func setup(app: DemoApp, market: bool, screen_busy: Callable) -> void:
	_app = app
	_market = market
	_shelf = app.controller.campaign_shelf(market)
	_screen_busy = screen_busy
	_offers.add_theme_constant_override("separation", 8)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(RULE_WIDTH, 0)
	_prompt.add_theme_color_override("font_color", ScreenKit.RED)
	tray.side_buttons = true
	tray.compact = true
	tray.setup(app.controller)
	tray.changed.connect(_show_prompt)
	tray.used.connect(_on_used)
	_flier.top_level = true
	_flier.z_index = 2
	_flier.visible = false
	_flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(_flier)


## A column holding what the shop already shows there, with the Campaign offer under it.
func beside(column: Control) -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.add_child(column)
	stack.add_child(_offers)
	return stack


func is_busy() -> bool:
	return _busy


## Rebuilds the offer and the tray from the counter.
func show_offer() -> void:
	for child: Node in _offers.get_children():
		if child == _prompt:
			continue
		_offers.remove_child(child)
		child.queue_free()
	if _prompt.get_parent() == null:
		_offers.add_child(_prompt)
	var stock: Array[String] = _shelf.stock()
	for slot: int in stock.size():
		var offer: Control = _offer(slot, stock[slot])
		_offers.add_child(offer)
		_offers.move_child(offer, slot)
	tray.enabled = not _busy
	tray.refresh()
	_show_prompt()


func _offer(slot: int, campaign_id: String) -> Control:
	var controller: RunController = _app.controller
	if campaign_id.is_empty():
		var sold: Label = ScreenKit.styled(tr("store.sold"), CommonsTheme.TITLE)
		sold.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
		return sold
	var leaflet: CampaignLeaflet = CampaignLeaflet.new()
	leaflet.set_compact(true)
	var rule: String = controller.campaign_text(campaign_id)
	var name: String = controller.campaign_name(campaign_id)
	leaflet.show_campaign(-1, campaign_id, name, rule, controller.is_private_campaign(campaign_id))
	var text: KeywordText = KeywordText.new()
	text.custom_minimum_size = Vector2(RULE_WIDTH, 0)
	text.add_theme_font_size_override("normal_font_size", RULE_SIZE)
	text.add_theme_color_override("default_color", ScreenKit.STYLE.paper_bright)
	text.set_rule(rule)
	var buy: Button = ScreenKit.button(
		tr("store.buy").format({"price": _shelf.price(slot)}), CommonsTheme.COUPON
	)
	buy.disabled = not _shelf.can_buy(slot)
	buy.tooltip_text = tr("campaign.full") if _shelf.is_full() else Keywords.wrapped(rule)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.custom_minimum_size = Vector2.ZERO
	buy.pressed.connect(_buy.bind(slot, leaflet))
	return ScreenKit.row([leaflet, text, buy], 12)


## Buys the offer and flies its leaflet into the tray's next place.
func _buy(slot: int, leaflet: CampaignLeaflet) -> void:
	if _busy or (_screen_busy.is_valid() and _screen_busy.call()):
		return
	var held: int = _app.controller.held_campaigns().size()
	var from: Vector2 = leaflet.global_position
	if _app.controller.campaign_buy(slot, _market) != RunController.OK:
		show_offer()
		return
	Audio.play(AudioEvents.STORE_BUY)
	spent.emit()
	if UiMotion.reduced():
		show_offer()
		return
	_busy = true
	_flier.show_campaign(held, leaflet.campaign_id, leaflet.shown_name(), "", leaflet.is_private())
	_flier.set_compact(true)
	_flier.size = CampaignLeaflet.leaf_size(true)
	_flier.global_position = from
	_flier.scale = Vector2.ONE
	_flier.visible = true
	leaflet.modulate.a = 0.0
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
		_app.show_screen("set_summary", true)


## While a leaflet is armed its ask takes the offer's place, so the shelf keeps its height.
func _show_prompt() -> void:
	_prompt.text = tray.prompt()
	_prompt.visible = not _prompt.text.is_empty()
	for child: Node in _offers.get_children():
		if child != _prompt:
			(child as Control).visible = not _prompt.visible

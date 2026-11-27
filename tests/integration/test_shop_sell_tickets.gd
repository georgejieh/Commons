extends GdUnitTestSuite
## The Sell tickets follow what is held (ADR 0040): a Campaign bought into an empty tray
## place gets its ticket at once, a Campaign used in the shop moves the ones after it
## into its place with their own prices, and a "Sell for N?" waiting on a place whose item
## changed is taken back, so the second press never sells something else.

const SEED: int = 4242
const LOAN: String = "grain_loan"

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	_loop().state.coupons = 60
	_app.controller.reseal_book()
	Settings.set_value("reduced_motion", true)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _open() -> StoreScreen:
	var store: StoreScreen = _app.show_screen(ScreenId.STORE, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func _price_of(campaign_id: String) -> int:
	for definition: CampaignDef in RunCampaigns.all():
		if definition.id == campaign_id:
			return _loop().visit.shop.campaigns.sale_price(definition)
	return -1


## The ticket on a tray place, shown as hover shows it.
func _ticket(store: StoreScreen, slot: int) -> SellTag:
	var stall: CampaignStall = store.campaign_stall
	var sale: SellDesk = store.sale
	var leaflet: CampaignLeaflet = stall.tray.leaflet(slot)
	var tag: SellTag = sale.tag_on(leaflet)
	if tag != null:
		leaflet.mouse_entered.emit()
	return tag


func test_a_campaign_bought_into_an_empty_tray_gets_its_ticket() -> void:
	_loop().state.inventory.consumables.clear()
	_app.controller.reseal_book()
	var store: StoreScreen = await _open()
	var stall: CampaignStall = store.campaign_stall
	var bought: String = _loop().visit.shop.campaigns.stock()[0]
	stall.panel(0).buy.pressed.emit()
	await await_idle_frame()
	assert_array(_app.controller.items.held_campaigns()).is_equal([bought])
	var tag: SellTag = _ticket(store, 0)
	assert_object(tag).is_not_null()
	assert_bool(tag.visible).is_true()
	assert_str(tag.button.text).is_equal(tr("store.sell").format({"price": _price_of(bought)}))


func test_a_campaign_used_in_the_shop_moves_the_next_with_its_own_price() -> void:
	var next: String = ""
	for definition: CampaignDef in RunCampaigns.all():
		if definition.id != LOAN and _price_of(definition.id) != _price_of(LOAN):
			next = definition.id
			break
	assert_str(next).is_not_empty()
	_loop().state.inventory.consumables.assign([LOAN, next])
	_app.controller.reseal_book()
	var store: StoreScreen = await _open()
	var stall: CampaignStall = store.campaign_stall
	# A sale asked for on the second place, then the loan in the first is used.
	var second: SellTag = _ticket(store, 1)
	second.press()
	assert_bool(second.is_asking()).is_true()
	var first: SellTag = _ticket(store, 0)
	first.press()
	assert_bool(first.is_asking()).is_true()
	stall.tray.arm(0)
	stall.tray.use_armed()
	await await_idle_frame()
	assert_array(_app.controller.items.held_campaigns()).is_equal([next])
	var moved: SellTag = _ticket(store, 0)
	assert_bool(moved.is_asking()).is_false()
	assert_str(moved.button.text).is_equal(tr("store.sell").format({"price": _price_of(next)}))
	assert_bool(second.is_asking()).is_false()
	# A press on the moved ticket only asks; nothing is sold by the earlier question.
	moved.press()
	assert_array(_app.controller.items.held_campaigns()).is_equal([next])

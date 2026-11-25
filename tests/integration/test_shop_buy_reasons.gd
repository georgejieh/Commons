extends GdUnitTestSuite
## A Buy button that cannot be pressed still reads and says why (commons-screens
## states.md, "a disabled choice says why, where it stands"): short of coupons it says
## what is needed, with a full board it says there is no room, and its words are dark
## ink on the faded ticket. The reroll reads when off, and the black market's plot cards
## say Buy like every other price.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_shop_buy_reasons/run.json"
const FIVE: Array[String] = ["iron_rice_bowl", "red_banner", "peek", "stakhanovite", "red_ink"]

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()


func after_test() -> void:
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _open(screen_id: String) -> StoreScreen:
	var store: StoreScreen = _app.show_screen(screen_id, true)
	await await_idle_frame()
	return store


func _cadre_buy(store: StoreScreen, slot: int) -> Button:
	var counter: HBoxContainer = store.get("_counter")
	return counter.get_child(slot).find_children("*", "Button", true, false)[0]


func _assert_readable(button: Button, where: String) -> void:
	assert_bool(button.disabled).override_failure_message(where + " is on").is_true()
	var ink: Color = button.get_theme_color("font_disabled_color")
	assert_float(ink.get_luminance()).override_failure_message(where).is_less(0.2)
	assert_float(ink.a).override_failure_message(where).is_greater_equal(0.8)


func test_short_of_coupons_every_buy_says_what_it_needs() -> void:
	_loop().state.coupons = 0
	_app.controller.reseal_book()
	var store: StoreScreen = await _open("store")
	var desk: ShopDesk = _app.controller.desk(false)
	var buy: Button = _cadre_buy(store, 0)
	_assert_readable(buy, "cadre")
	assert_str(buy.text).is_equal(tr("store.buy.poor").format({"price": desk.price(0)}))
	var directives: DirectiveRow = store.get("_directives")
	var issue: Button = directives.find_children("*", "Button", true, false)[0]
	_assert_readable(issue, "directive")
	assert_str(issue.text).is_equal(tr("store.buy.poor").format({"price": desk.directive_price(0)}))
	for stall: String in ["_campaign_stall", "_reform_stall", "_envelope_stall"]:
		var owner: Object = store.get(stall)
		var panel: CounterPanel = owner.call("panel", 0)
		if panel == null or not panel.buy.visible:
			continue
		_assert_readable(panel.buy, stall)
		assert_str(panel.buy.text).override_failure_message(stall).starts_with(
			tr("store.buy.poor").split("{")[0]
		)
	var reroll: Button = store.get("_reroll")
	_assert_readable(reroll, "reroll")


func test_with_a_full_board_a_cadre_says_there_is_no_room() -> void:
	_loop().state.coupons = 40
	_loop().state.inventory.cadres.assign(FIVE)
	_app.controller.reseal_book()
	var market: StoreScreen = await _open("black_market")
	var desk: ShopDesk = _app.controller.desk(true)
	for slot: int in desk.stock().size():
		if desk.stock()[slot].is_empty():
			continue
		var buy: Button = _cadre_buy(market, slot)
		_assert_readable(buy, "cadre %d" % slot)
		assert_str(buy.text).is_equal(tr("store.buy.full").format({"price": desk.price(slot)}))


func test_plot_cards_say_buy_and_their_price() -> void:
	_loop().state.coupons = 40
	_app.controller.reseal_book()
	var market: StoreScreen = await _open("black_market")
	var goods: MarketGoods = market.get("_goods")
	var desk: ShopDesk = _app.controller.desk(true)
	var button: Button = goods.card_button(0)
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_false()
	assert_str(button.text).is_equal(tr("store.buy").format({"price": desk.plot_card_price(0)}))


## A Campaign sold back this visit says so on the copy still on the shelf, whatever the
## coupons, and cannot be pressed (ADR 0040).
func test_a_campaign_sold_back_says_it_returns_next_visit() -> void:
	_loop().state.coupons = 40
	var campaign_id: String = _loop().visit.shop.campaigns.stock()[0]
	_loop().state.inventory.consumables.append(campaign_id)
	_app.controller.reseal_book()
	var index: int = _loop().state.inventory.consumables.size() - 1
	assert_int(_app.controller.sell_campaign(index)).is_equal(RunLoop.Reason.OK)
	var store: StoreScreen = await _open("store")
	var stall: Object = store.get("_campaign_stall")
	var panel: CounterPanel = stall.call("panel", 0)
	_assert_readable(panel.buy, "sold back campaign")
	assert_str(panel.buy.text).is_equal(tr("store.buy.sold_back"))
	assert_bool(_app.controller.campaign_shelf(false).is_sold_back(0)).is_true()


## The same for a Cadre sold back while a counter still offers it.
func test_a_cadre_sold_back_says_it_returns_next_visit() -> void:
	_loop().state.coupons = 40
	var cadre_id: String = _loop().visit.shop.stock()[0]
	_loop().state.inventory.cadres.append(cadre_id)
	_app.controller.reseal_book()
	var index: int = _loop().state.inventory.cadres.size() - 1
	assert_int(_app.controller.sell_cadre(index)).is_equal(RunLoop.Reason.OK)
	var store: StoreScreen = await _open("store")
	var buy: Button = _cadre_buy(store, 0)
	_assert_readable(buy, "sold back cadre")
	assert_str(buy.text).is_equal(tr("store.buy.sold_back"))

extends GdUnitTestSuite
## Selling back in the shops (ADR 0040): in both shops each held Cadre on the board and
## each held Campaign in the tray shows a Sell ticket naming what it pays while hovered or
## focused; the first press only asks again, leaving the paper takes the question back,
## and the second press sells, counting the coupons up, freeing the place and clearing
## "No room" on the counter in the same visit. Keyboard focus reaches it and shows the
## item's slip beside it. At both window sizes and every text size the ticket and the
## slip stay on the screen, and the slip keeps off the ticket.

const SEED: int = 4242
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.0

static var _save_path: String = TestFolder.of("test_shop_sell_ui") + "run.json"

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.coupons = 60
	_app.controller.reseal_book()
	Settings.set_value("reduced_motion", true)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Holds count Cadres the counters do not offer, and one Campaign.
func _hold(count: int) -> void:
	var state: RunState = _loop().state
	var offered: Array[String] = _loop().visit.shop.stock() + _loop().visit.market.stock()
	for definition: ModifierDef in RunLoop.all_cadres():
		if state.inventory.cadres.size() >= count:
			break
		if not state.inventory.cadres.has(definition.id) and not offered.has(definition.id):
			state.inventory.cadres.append(definition.id)
	if state.inventory.consumables.is_empty():
		state.inventory.consumables.append(RunCampaigns.all()[0].id)
	_app.controller.reseal_book()


func _open(screen_id: String) -> StoreScreen:
	var store: StoreScreen = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func _tiles(store: StoreScreen) -> Array[Control]:
	var board: NoticeBoard = store.get("_board")
	var tiles: Array[Control] = []
	for node: Node in board.get_children():
		if node is TipHost:
			tiles.append(node as Control)
	return tiles


func test_a_cadre_sells_in_two_presses_at_either_shop() -> void:
	for screen_id: String in ["store", "black_market"]:
		_hold(2)
		var store: StoreScreen = await _open(screen_id)
		var sale: SellDesk = store.get("_sale")
		var desk: ShopDesk = _app.controller.store.desk(screen_id == "black_market")
		var tile: Control = _tiles(store)[0]
		var tag: SellTag = sale.tag_on(tile)
		assert_object(tag).override_failure_message(screen_id).is_not_null()
		assert_bool(tag.visible).is_false()
		tile.mouse_entered.emit()
		assert_bool(tag.visible).is_true()
		var paid: int = desk.sale(0)
		assert_int(paid).is_greater(0)
		assert_str(tag.button.text).contains(str(paid))
		var held: Array[String] = _app.controller.state_copy().inventory.cadres
		var coupons: int = _app.controller.state_copy().coupons
		tag.button.pressed.emit()
		assert_bool(tag.is_asking()).is_true()
		assert_str(tag.button.text).is_equal(tr("store.sell.confirm").format({"price": paid}))
		assert_array(_app.controller.state_copy().inventory.cadres).is_equal(held)
		# Leaving the paper takes the question back.
		tile.mouse_exited.emit()
		assert_bool(tag.is_asking()).is_false()
		tile.mouse_entered.emit()
		tag.button.pressed.emit()
		tag.button.pressed.emit()
		await await_idle_frame()
		var state: RunState = _app.controller.state_copy()
		assert_int(state.inventory.cadres.size()).is_equal(held.size() - 1)
		assert_array(state.inventory.cadres).not_contains([held[0]])
		assert_int(state.coupons).is_equal(coupons + paid)
		var shown: Label = store.get("_coupons")
		assert_str(shown.text).contains(str(state.coupons))
		tile.mouse_exited.emit()


func test_selling_clears_no_room_on_the_counter_in_the_same_visit() -> void:
	_hold(RunReforms.cadre_slots(_loop().state))
	var store: StoreScreen = await _open("store")
	var cadres: CadreCounter = store.get("_cadres")
	var counter: HBoxContainer = cadres.row
	var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	assert_str(buy.text).is_equal(tr("store.buy.full"))
	var tile: Control = _tiles(store)[0]
	var tag: SellTag = _sale(store).tag_on(tile)
	tile.mouse_entered.emit()
	tag.press()
	tag.press()
	await await_idle_frame()
	buy = counter.get_child(0).find_children("*", "Button", true, false)[0]
	assert_bool(buy.disabled).is_false()
	assert_str(buy.text).is_not_equal(tr("store.buy.full"))


func test_a_held_campaign_sells_from_the_tray() -> void:
	_hold(1)
	var store: StoreScreen = await _open("store")
	var stall: CampaignStall = store.get("_campaign_stall")
	var leaflet: CampaignLeaflet = stall.tray.leaflet(0)
	var tag: SellTag = _sale(store).tag_on(leaflet)
	assert_object(tag).is_not_null()
	var held: int = _app.controller.items.held_campaigns().size()
	var coupons: int = _app.controller.state_copy().coupons
	var paid: int = _app.controller.store.desk(false).sale(0, true)
	leaflet.mouse_entered.emit()
	tag.press()
	assert_int(_app.controller.items.held_campaigns().size()).is_equal(held)
	tag.press()
	await await_idle_frame()
	assert_int(_app.controller.items.held_campaigns().size()).is_equal(held - 1)
	assert_int(_app.controller.state_copy().coupons).is_equal(coupons + paid)


func test_the_keyboard_reaches_a_sale_and_the_slip_stands_beside_it() -> void:
	_hold(2)
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			for screen_id: String in ["store", "black_market"]:
				var store: StoreScreen = await _open(screen_id)
				var where: String = "%s %s text %d" % [screen_id, screen_size, level]
				await _check_focus(store, where)


func _check_focus(store: StoreScreen, where: String) -> void:
	var tile: Control = _tiles(store)[0]
	var tag: SellTag = _sale(store).tag_on(tile)
	assert_int(tile.focus_mode).override_failure_message(where).is_equal(Control.FOCUS_ALL)
	tile.grab_focus()
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(tag.visible).override_failure_message(where).is_true()
	var slip: DetailSlip = store.slip()
	assert_object(slip.anchor()).override_failure_message(where).is_same(tile)
	var ticket: Rect2 = tag.button.get_global_rect()
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	assert_bool(screen.encloses(ticket)).override_failure_message(where + " ticket").is_true()
	var paper: Rect2 = slip.get_global_rect()
	assert_bool(screen.encloses(paper)).override_failure_message(where + " slip").is_true()
	(
		assert_bool(paper.grow(-SLACK).intersects(ticket))
		. override_failure_message("%s: slip %s on the ticket %s" % [where, paper, ticket])
		. is_false()
	)
	(
		assert_float(SlipPlacer.distance(paper, tile.get_global_rect()))
		. override_failure_message(where + " slip far")
		. is_less_equal(SlipPlacer.REACH + SLACK)
	)
	var accept: InputEventAction = InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	tile.gui_input.emit(accept)
	assert_bool(tag.is_asking()).override_failure_message(where).is_true()
	tile.release_focus()
	await await_idle_frame()
	assert_bool(tag.is_asking()).override_failure_message(where).is_false()


func _sale(store: StoreScreen) -> SellDesk:
	var sale: SellDesk = store.get("_sale")
	return sale

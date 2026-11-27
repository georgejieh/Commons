extends GdUnitTestSuite
## Reforms on screen (ADR 0021): the state store's offer is a decree on the counter whose
## rules the shared slip shows clear of it; buying stamps it "Enacted", holds every other
## purchase while it flies, and pins it to the strip of Reforms in force, which both shops
## show and whose slips explain themselves; reduced motion skips the show; nothing is left
## behind; Enlarged Committee gives both boards six slots and Courier's Bag the tray three;
## the Set intro names what is in force; and the decree paper is aged and wears.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_reform_ui/run.json"
const WAIT_SECONDS: float = 4.0

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
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
	_loop().state.coupons = 60
	_app.controller.reseal_book()


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", false)
	ArtStages.stage_override = -1
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


func _open(screen_id: String = "store") -> StoreScreen:
	var store: StoreScreen = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func _stall(store: StoreScreen) -> ReformStall:
	return store.get("_reform_stall")


func _wait(store: StoreScreen) -> void:
	var waited: float = 0.0
	while store.is_issuing() and waited < WAIT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


func test_the_store_offers_a_decree_explained_by_the_slip() -> void:
	var store: StoreScreen = await _open()
	var offered: String = _app.controller.reform_shelf().stock()[0]
	var panel: CounterPanel = _stall(store).panel(0)
	assert_object(panel).is_not_null()
	assert_int(panel.look()).is_equal(CounterPanel.Look.DECREE)
	assert_str(panel.shown_name()).is_equal(_app.controller.reform_name(offered))
	assert_bool(panel.buy.disabled).is_false()
	panel.described.emit(panel)
	await await_idle_frame()
	var slip: DetailSlip = store.slip()
	assert_bool(slip.visible).is_true()
	assert_str(slip.shown_rule()).is_equal(_app.controller.reform_text(offered))
	assert_bool(slip.get_global_rect().intersects(panel.get_global_rect())).is_false()
	assert_bool(Rect2(0, 0, 1920, 1080).encloses(slip.get_global_rect())).is_true()
	# It only explains: clicks go through it to whatever lies under.
	for node: Node in [slip] + slip.find_children("*", "Control", true, false):
		assert_int((node as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	panel.left.emit(panel)
	assert_bool(slip.visible).is_false()
	# Every rule names its numbers from data, and none is left unfilled.
	for reform_id: String in ["enlarged_committee", "couriers_bag", "grain_reserve"]:
		assert_str(_app.controller.reform_text(reform_id)).not_contains("{")
	assert_str(_app.controller.reform_text("enlarged_committee")).contains("6")
	assert_str(_app.controller.reform_text("couriers_bag")).contains("3")


func test_enacting_stamps_holds_purchases_and_pins_the_decree() -> void:
	var store: StoreScreen = await _open()
	var stall: ReformStall = _stall(store)
	var offered: String = _app.controller.reform_shelf().stock()[0]
	var children: int = store.find_children("*", "", true, false).size()
	var commands: int = _loop().record.commands.size()
	stall.panel(0).buy.pressed.emit()
	assert_array(_app.controller.held_reforms()).is_equal([offered])
	assert_int(_loop().record.commands.size()).is_equal(commands + 1)
	assert_bool(stall.is_busy()).is_true()
	assert_bool(store.is_issuing()).is_true()
	assert_bool(stall.seal().visible).is_true()
	assert_str(stall.seal().word()).is_equal(tr("reform.enacted").to_upper())
	# Nothing else is bought while the decree is in the air.
	var cadres: int = _app.controller.state_copy().inventory.cadres.size()
	var counter: HBoxContainer = store.get("_counter")
	var cadre_buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	cadre_buy.pressed.emit()
	var campaigns: CampaignStall = store.get("_campaign_stall")
	campaigns.panel(0).buy.pressed.emit()
	var reroll: Button = store.get("_reroll")
	reroll.pressed.emit()
	assert_int(_app.controller.state_copy().inventory.cadres.size()).is_equal(cadres)
	assert_int(_loop().record.commands.size()).is_equal(commands + 1)
	await _wait(store)
	assert_bool(stall.is_busy()).is_false()
	assert_bool(stall.seal().visible).is_false()
	assert_int(stall.strip.held_count()).is_equal(1)
	var tag: Control = stall.strip.tag(0)
	assert_bool(tag.visible).is_true()
	# The offer is spent; the counter shows the place enacted.
	assert_object(stall.panel(0)).is_not_null()
	assert_bool(stall.panel(0).buy.visible).is_false()
	await await_idle_frame()
	assert_int(store.find_children("*", "", true, false).size()).is_less_equal(children + 2)
	tag.focus_entered.emit()
	assert_str(store.slip().shown_rule()).is_equal(_app.controller.reform_text(offered))
	assert_bool(store.slip().get_global_rect().intersects(tag.get_global_rect())).is_false()


func test_reduced_motion_enacts_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var store: StoreScreen = await _open()
	var stall: ReformStall = _stall(store)
	stall.panel(0).buy.pressed.emit()
	assert_bool(stall.is_busy()).is_false()
	assert_bool(stall.seal().visible).is_false()
	assert_int(stall.strip.held_count()).is_equal(1)


func test_without_coupons_the_offer_cannot_be_bought() -> void:
	_loop().state.coupons = 0
	_app.controller.reseal_book()
	var store: StoreScreen = await _open()
	var stall: ReformStall = _stall(store)
	assert_bool(stall.panel(0).buy.disabled).is_true()
	assert_int(_app.controller.reform(0)).is_not_equal(RunController.OK)
	assert_array(_app.controller.held_reforms()).is_empty()


func test_the_black_market_shows_the_strip_and_no_offer() -> void:
	_loop().state.reforms.assign(["grain_reserve", "couriers_bag"])
	var market: StoreScreen = await _open("black_market")
	var stall: ReformStall = _stall(market)
	assert_object(stall.panel(0)).is_null()
	assert_int(stall.strip.held_count()).is_equal(2)
	assert_bool(stall.strip.is_visible_in_tree()).is_true()


func test_enlarged_committee_gives_both_boards_six_slots() -> void:
	var store: StoreScreen = await _open()
	var five: NoticeBoard = store.get("_board")
	assert_int(five.slot_count()).is_equal(5)
	_loop().state.reforms.append("enlarged_committee")
	store = await _open()
	var board: NoticeBoard = store.get("_board")
	assert_int(board.slot_count()).is_equal(6)
	_app.controller.leave_store()
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_PLAY:
		driver.act(_app.controller)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	var notice: NoticeBoard = table.get("_board")
	assert_int(notice.slot_count()).is_equal(6)
	var area: Rect2 = notice.get_global_rect()
	var cards: Array[TipHost] = notice.get("_cards")
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	for card: TipHost in cards:
		assert_bool(area.encloses(card.get_global_rect())).is_true()
		for seat: SeatPanel in seats.values():
			assert_bool(card.get_global_rect().intersects(seat.get_global_rect())).is_false()


func test_couriers_bag_gives_the_shop_tray_three_places() -> void:
	_loop().state.reforms.append("couriers_bag")
	var store: StoreScreen = await _open()
	var stall: CampaignStall = store.get("_campaign_stall")
	var tray: CampaignTray = stall.tray
	assert_int(tray.campaign_count()).is_equal(3)


func test_the_set_intro_names_the_reforms_in_force() -> void:
	_loop().state.reforms.assign(["work_point_reform", "unplanned_economy"])
	_app.controller.leave_store()
	var intro: Control = _app.show_screen("set_intro", true)
	await await_idle_frame()
	var line: String = tr("reform.held_line").format(
		{
			"names":
			"%s, %s" % [tr("reform.work_point_reform.name"), tr("reform.unplanned_economy.name")]
		}
	)
	var found: bool = false
	for node: Node in intro.find_children("*", "Label", true, false):
		found = found or (node as Label).text == line
	assert_bool(found).is_true()


## A Set intro with more on it than the page is tall is drawn smaller, so Begin is
## never off the screen: every Reform in force makes the sheet too tall.
func test_a_set_intro_too_tall_for_the_page_keeps_begin_on_screen() -> void:
	var held: Array[String] = []
	for reform: ReformDef in RunReforms.POOL.reforms:
		held.append(reform.id)
	_loop().state.reforms.assign(held)
	_app.controller.leave_store()
	var intro: Control = _app.show_screen("set_intro", true)
	await await_idle_frame()
	await await_idle_frame()
	var begin: Button = null
	for node: Node in intro.find_children("*", "Button", true, false):
		if (node as Button).text == tr("intro.begin"):
			begin = node as Button
	assert_object(begin).is_not_null()
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	var box: Rect2 = begin.get_global_rect()
	assert_bool(screen.encloses(box)).override_failure_message(str(box)).is_true()
	# The sheet was in fact too tall, and was drawn smaller to fit.
	var panel: Control = ScreenKit.card_panel(begin.get_parent() as VBoxContainer)
	assert_float(panel.scale.y).is_less(1.0)


## Nothing drawn is clean: decree paper is aged at stage 0 and more so at the last.
func test_decree_paper_is_aged_and_wears_with_the_stage() -> void:
	ArtStages.stage_override = 0
	var fresh: Color = DecreePaper.paper(BowlGrime.wear())
	assert_bool(fresh.is_equal_approx(Color.WHITE)).is_false()
	assert_bool(fresh.is_equal_approx(DecreePaper.PAPER)).is_false()
	var store: StoreScreen = await _open()
	var panel: CounterPanel = _stall(store).panel(0)
	panel.queue_redraw()
	await await_idle_frame()
	ArtStages.stage_override = BoardState.CORRUPTION_STAGES - 1
	var worn: Color = DecreePaper.paper(BowlGrime.wear())
	assert_float(worn.get_luminance()).is_less(fresh.get_luminance())
	panel.queue_redraw()
	_stall(store).strip.queue_redraw()
	await await_idle_frame()

extends GdUnitTestSuite
## The shop's small pieces read cleanly at every text size and both window sizes: an
## empty Cadre board says what goes there, "Not now" on a held Campaign is 16 px or more,
## the Campaigns head keeps clear of the leaflets under it, the papers on the counter
## share one top and one height, and "None yet" stands on its label's baseline.

const SEED: int = 4242
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.0

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	_loop().state.coupons = 60
	_app.controller.reseal_book()


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _open(screen_id: String) -> StoreScreen:
	var store: StoreScreen = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func test_an_empty_board_says_what_goes_there() -> void:
	_loop().state.inventory.cadres.clear()
	var store: StoreScreen = await _open("store")
	var board: NoticeBoard = store.get("_board")
	assert_bool(board.shows_empty_line()).is_true()
	assert_str(board.empty_line).is_equal(tr("store.shelf.empty"))
	_loop().state.inventory.cadres.assign(["canteen"])
	store = await _open("store")
	board = store.get("_board")
	assert_bool(board.shows_empty_line()).is_false()


func test_the_pieces_read_at_every_size() -> void:
	# Campaign Envelope and Grain Loan cannot be used here, so each leaflet says Not now.
	_loop().state.inventory.consumables.assign(["mutual_aid", "overfulfillment"])
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			for screen_id: String in ["store", "black_market"]:
				var store: StoreScreen = await _open(screen_id)
				var where: String = "%s %s text %d" % [screen_id, screen_size, level]
				_check_tray(store, where)
				_check_counter(store, where)
				_check_strip(store, where)


func _check_tray(store: StoreScreen, where: String) -> void:
	var stall: CampaignStall = store.get("_campaign_stall")
	var tray: CampaignTray = stall.tray
	var head: Label = tray.get("_head")
	var first: CampaignLeaflet = tray.leaflet(0)
	var gap: float = first.get_global_rect().position.y - head.get_global_rect().end.y
	assert_float(gap).override_failure_message(where + " head on leaflet").is_greater_equal(
		CampaignTray.HEAD_CLEAR - SLACK
	)
	assert_bool(first.says_not_now()).override_failure_message(where).is_true()
	var status: Label = first.get("_status")
	assert_int(status.get_theme_font_size("font_size")).is_greater_equal(16)


func _check_counter(store: StoreScreen, where: String) -> void:
	var papers: Array[CounterPanel] = []
	for name: String in ["_campaign_stall", "_reform_stall", "_envelope_stall"]:
		var owner: Object = store.get(name)
		var panel: CounterPanel = owner.call("panel", 0)
		if panel != null:
			papers.append(panel)
	assert_int(papers.size()).override_failure_message(where).is_greater_equal(2)
	var first: Rect2 = papers[0].get_global_rect()
	for panel: CounterPanel in papers:
		var rect: Rect2 = panel.get_global_rect()
		(
			assert_bool(
				(
					absf(rect.position.y - first.position.y) < SLACK
					and absf(rect.size.y - first.size.y) < SLACK
				)
			)
			. override_failure_message("%s: %s against %s" % [where, rect, first])
			. is_true()
		)


func _check_strip(store: StoreScreen, where: String) -> void:
	var stall: ReformStall = store.get("_reform_stall")
	var head: Label = stall.strip.get("_head")
	var none: Label = stall.strip.get("_none")
	if not none.is_visible_in_tree():
		return
	var head_at: float = head.get_global_rect().position.y + _baseline(head)
	var none_at: float = none.get_global_rect().position.y + _baseline(none)
	assert_float(absf(head_at - none_at)).override_failure_message(where + " baseline").is_less(1.5)


## Where a label's baseline is drawn inside it: centred text, below any top margin.
func _baseline(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var px: int = label.get_theme_font_size("font_size")
	var top: float = label.get_theme_stylebox("normal").content_margin_top
	var bottom: float = label.get_theme_stylebox("normal").content_margin_bottom
	var room: float = label.size.y - maxf(top, 0.0) - maxf(bottom, 0.0)
	var ascent: float = font.get_ascent(px)
	return maxf(top, 0.0) + (room - ascent - font.get_descent(px)) / 2.0 + ascent

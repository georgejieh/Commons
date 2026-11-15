extends GdUnitTestSuite
## Both shops fit the screen (ADR 0021): at 1920x1080 and at the Steam Deck's 1280x800,
## every visible control lies inside the screen and no two of the page's main blocks
## overlap, both with a fresh run and with the most a run can hold: six Cadres, three
## Campaigns, all six Reforms in force, rationing's note and the two tallest Directives.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_shop_layout/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
const SIX: Array[String] = [
	"iron_rice_bowl", "canteen", "red_banner", "peek", "stakhanovite", "red_ink"
]
const ALL_REFORMS: Array[String] = [
	"supply_cooperative",
	"work_point_reform",
	"enlarged_committee",
	"grain_reserve",
	"couriers_bag",
	"unplanned_economy",
]

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
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
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


## Hands the run the most it can hold, behind the controller, as only tests do.
func _fill() -> void:
	var state: RunState = _loop().state
	state.reforms.assign(ALL_REFORMS)
	state.inventory.cadres.assign(SIX)
	state.inventory.consumables.assign(["grain_loan", "seizure_notice", "mutual_aid"])
	state.rationed = true
	state.coupons = 999
	state.resentment = 88
	var tall: Array[String] = ["on_combined_brigades", "on_launching_satellites"]
	_loop().shop.set("_directive_stock", tall)


func test_both_shops_fit_a_fresh_run() -> void:
	_loop().state.coupons = 60
	await _check_all("fresh")


func test_both_shops_fit_the_most_a_run_holds() -> void:
	_fill()
	await _check_all("full")
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	var board: NoticeBoard = store.get("_board")
	assert_int(board.slot_count()).is_equal(6)
	var stall: CampaignStall = store.get("_campaign_stall")
	assert_int(stall.tray.campaign_count()).is_equal(3)
	var reforms: ReformStall = store.get("_reform_stall")
	assert_int(reforms.strip.held_count()).is_equal(6)


func _check_all(where: String) -> void:
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		for screen_id: String in ["store", "black_market"]:
			var store: StoreScreen = _app.show_screen(screen_id, true)
			await await_idle_frame()
			await await_idle_frame()
			var label: String = "%s %s %s" % [where, screen_id, screen_size]
			_check_inside(store, label)
			_check_blocks(store, label)


func _check_inside(root: Node, where: String) -> void:
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control is TextureRect or control is ColorRect:
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x < -1000.0:
			continue
		(
			assert_bool(screen.encloses(rect))
			. override_failure_message("%s: %s at %s" % [where, control.get_path(), rect])
			. is_true()
		)


func _check_blocks(store: StoreScreen, where: String) -> void:
	var blocks: Dictionary[String, Control] = store.blocks()
	assert_int(blocks.size()).is_equal(7)
	var names: Array[String] = blocks.keys()
	for first: int in names.size():
		for second: int in range(first + 1, names.size()):
			var a: Rect2 = blocks[names[first]].get_global_rect().grow(-SLACK)
			var b: Rect2 = blocks[names[second]].get_global_rect().grow(-SLACK)
			(
				assert_bool(a.intersects(b))
				. override_failure_message(
					"%s: %s %s overlaps %s %s" % [where, names[first], a, names[second], b]
				)
				. is_false()
			)


## Coming back from the black market shows the store again, whole, with its way out.
func test_returning_from_the_black_market_shows_the_store_whole() -> void:
	get_tree().root.size = SIZES[0]
	_app.show_screen("store", true)
	await await_idle_frame()
	var market: StoreScreen = _app.show_screen("black_market")
	await await_idle_frame()
	var back: Button = null
	for node: Node in market.find_children("*", "Button", true, false):
		if (node as Button).text == tr("market.back"):
			back = node
	assert_object(back).is_not_null()
	back.pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	var switcher: SceneSwitcher = _app.get("switcher")
	var store: Node = switcher.current()
	assert_bool(store is StoreScreen).is_true()
	var leave: int = 0
	for node: Node in store.find_children("*", "Button", true, false):
		if (node as Button).text == tr("store.leave"):
			leave += 1
	assert_int(leave).is_equal(1)
	_check_inside(store, "returned store")


## The rank picker opens whole on the screen over the black market's counter, so its
## Cancel can be reached.
func test_the_rank_picker_opens_on_the_screen() -> void:
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		_loop().state.coupons = 40
		var offered: Array[String] = ["rehabilitation", "steel_target", "last_sheaf"]
		_loop().market.set("_stock", offered)
		var market: StoreScreen = _app.show_screen("black_market", true)
		await await_idle_frame()
		var counter: HBoxContainer = market.get("_counter")
		var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
		buy.pressed.emit()
		await await_idle_frame()
		var picker: RankPicker = market.get("_picker")
		assert_bool(picker.is_open()).is_true()
		var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
		assert_bool(screen.encloses(picker.get_global_rect())).is_true()
		picker.close()


## An envelope open over each shop fits both screens with three choices and with four,
## Supply Cooperative's: every visible piece on screen, no two papers overlapping, and
## the heading, row, explanation and Take Nothing apart.
func test_an_open_envelope_fits_with_three_and_four_choices() -> void:
	Settings.set_value("reduced_motion", true)
	for reforms: Array[String] in [[] as Array[String], ["supply_cooperative"] as Array[String]]:
		_loop().state.reforms.assign(reforms)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			for kind: String in ["directive_envelope", "campaign_envelope", "parcel"]:
				var screen_id: String = "black_market" if kind == "parcel" else "store"
				_loop().state.coupons = 60
				_loop().shop.envelopes.clear()
				_loop().market.envelopes.clear()
				var stock: Array[String] = [kind]
				var counter: EnvelopeCounter = _loop().market.envelopes
				if kind != "parcel":
					counter = _loop().shop.envelopes
				counter.set("_stock", stock)
				var store: StoreScreen = _app.show_screen(screen_id, true)
				await await_idle_frame()
				var stall: EnvelopeStall = store.get("_envelope_stall")
				stall.panel(0).buy.pressed.emit()
				await await_idle_frame()
				await await_idle_frame()
				var overlay: EnvelopeOverlay = stall.overlay()
				var label: String = "%s %s %d" % [kind, screen_size, 3 + reforms.size()]
				assert_int(overlay.papers().size()).is_equal(3 + reforms.size())
				_check_inside(overlay, label)
				_check_apart(overlay, label)
				overlay.nothing_button().pressed.emit()
				await await_idle_frame()
	Settings.set_value("reduced_motion", false)


func _check_apart(overlay: EnvelopeOverlay, where: String) -> void:
	var pieces: Array[Control] = []
	for paper: ChoicePaper in overlay.papers():
		pieces.append(paper)
		var item: Rect2 = paper.item.get_global_rect()
		(
			assert_bool(paper.get_global_rect().grow(SLACK).encloses(item))
			. override_failure_message("%s: item %s outside its paper" % [where, item])
			. is_true()
		)
	var blocks: Dictionary[String, Control] = overlay.blocks()
	for name: String in ["heading", "detail", "button"]:
		pieces.append(blocks[name])
	for first: int in pieces.size():
		for second: int in range(first + 1, pieces.size()):
			var a: Rect2 = pieces[first].get_global_rect().grow(-SLACK)
			var b: Rect2 = pieces[second].get_global_rect().grow(-SLACK)
			(
				assert_bool(a.intersects(b))
				. override_failure_message("%s: %s overlaps %s" % [where, a, b])
				. is_false()
			)

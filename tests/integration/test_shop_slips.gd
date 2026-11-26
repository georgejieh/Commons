extends GdUnitTestSuite
## A slip stands right beside what it explains (commons-screens states.md, the owner's
## playtest of 2026-11-24): on both shops, at 1920x1080 and 1280x800 and at every text
## size, the slip for a Cadre on the counter, for each offer on the counter (the Campaign,
## the Reform and the envelope), for a Reform in force and for a keyword in a Cadre's
## rules lies wholly on the screen, within SlipPlacer.REACH of the thing it explains, and
## off that thing and its own button. It may lie on other papers.

const SEED: int = 4242
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.0
const FAR: Vector2 = Vector2(-500, -500)

static var _save_path: String = TestFolder.of("test_shop_slips") + "run.json"

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
	loop.state.reforms.assign(["unplanned_economy"])
	_app.controller.reseal_book()
	loop.visit.shop.set("_stock", ["canteen", "red_banner", "iron_rice_bowl"] as Array[String])
	loop.visit.market.set("_stock", ["loudspeaker", "steel_target", "last_sheaf"] as Array[String])


func after_test() -> void:
	var tips: KeywordTips = KeywordTips.of(self)
	tips.tick(10.0, FAR)
	tips.tick(10.0, FAR)
	tips.process_mode = Node.PROCESS_MODE_INHERIT
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_every_slip_on_both_shops_stands_beside_its_piece() -> void:
	Settings.set_value("reduced_motion", true)
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			for screen_id: String in ["store", "black_market"]:
				var store: StoreScreen = _app.show_screen(screen_id, true)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "%s %s text %d" % [screen_id, screen_size, level]
				await _check_details(store, where)
				await _check_keyword(store, where)


## The shared slip for every piece that asks for it.
func _check_details(store: StoreScreen, where: String) -> void:
	var slip: DetailSlip = store.slip()
	var cadres: CadreCounter = store.get("_cadres")
	var counter: HBoxContainer = cadres.row
	var card: Control = counter.get_child(0) as Control
	var buy: Button = card.find_children("*", "Button", true, false)[0]
	buy.focus_entered.emit()
	await _check_slip(store, slip, card.get_global_rect(), where + " cadre")
	buy.focus_exited.emit()
	var stalls: Array[Object] = [
		store.get("_campaign_stall"), store.get("_reform_stall"), store.get("_envelope_stall")
	]
	for stall: Object in stalls:
		var panel: CounterPanel = stall.call("panel", 0)
		if panel == null:
			continue
		panel.described.emit(panel)
		await _check_slip(store, slip, panel.get_global_rect(), where + " " + panel.title)
		panel.left.emit(panel)
	var reforms: ReformStall = store.get("_reform_stall")
	var tag: Control = reforms.strip.tag(0)
	tag.focus_entered.emit()
	await _check_slip(store, slip, tag.get_global_rect(), where + " in force")
	tag.focus_exited.emit()
	slip.hide_slip()


## The slip for a keyword in the first Cadre's rules, the pointer on its first line.
func _check_keyword(store: StoreScreen, where: String) -> void:
	var cadres: CadreCounter = store.get("_cadres")
	var counter: HBoxContainer = cadres.row
	var text: KeywordText = counter.get_child(0).find_children("*", "KeywordText", true, false)[0]
	var found: RegExMatch = RegEx.create_from_string("\\[url=([a-z_]+)\\]").search(text.text)
	assert_object(found).override_failure_message(where + " has no keyword").is_not_null()
	var tips: KeywordTips = KeywordTips.of(self)
	tips.process_mode = Node.PROCESS_MODE_DISABLED
	var at: Vector2 = text.get_global_rect().position + Vector2(60, 12)
	text.meta_hover_started.emit(found.get_string(1))
	tips.tick(KeywordTips.DELAY + 0.01, at)
	await await_idle_frame()
	await await_idle_frame()
	tips.tick(0.01, at)
	var keyword: KeywordSlip = tips.slips().back()
	assert_bool(keyword.placed).override_failure_message(where).is_true()
	var word: Rect2 = Rect2(at, Vector2.ZERO).grow(KeywordTips.POINTER)
	await _check_slip(store, keyword, word, where + " keyword")
	text.meta_hover_ended.emit(found.get_string(1))
	tips.tick(10.0, FAR)
	tips.tick(10.0, FAR)


func _check_slip(store: StoreScreen, paper: Control, anchor: Rect2, where: String) -> void:
	await await_idle_frame()
	assert_bool(paper.visible).override_failure_message(where + " slip closed").is_true()
	var slip: Rect2 = paper.get_global_rect()
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	(
		assert_bool(screen.encloses(slip))
		. override_failure_message("%s: slip %s off %s" % [where, slip, screen])
		. is_true()
	)
	var inner: Rect2 = slip.grow(-SLACK)
	(
		assert_bool(inner.intersects(anchor))
		. override_failure_message("%s: slip %s over its piece %s" % [where, slip, anchor])
		. is_false()
	)
	var reach: float = _gap(slip, anchor)
	(
		assert_float(reach)
		. override_failure_message("%s: slip %s is %.0f px from %s" % [where, slip, reach, anchor])
		. is_less_equal(SlipPlacer.REACH + SLACK)
	)
	# Its own button: any button that lies on the piece it explains.
	for node: Node in store.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		var box: Rect2 = button.get_global_rect()
		if not button.is_visible_in_tree() or not anchor.encloses(box):
			continue
		(
			assert_bool(inner.intersects(box))
			. override_failure_message("%s: slip %s over %s %s" % [where, slip, button.name, box])
			. is_false()
		)


## The gap between two rectangles: 0 when they touch or overlap.
func _gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()

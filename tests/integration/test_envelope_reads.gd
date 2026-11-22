extends GdUnitTestSuite
## An open envelope reads once and keeps clear: when no paper can be kept for one shared
## reason, the reason is said once under the envelope's name, each paper says only that it
## cannot be kept, and the explanation does not say it again; the column keeps a margin
## from the screen's top and bottom at every text size; and a kept paper's seal lies off
## its caption, with Take Nothing gone from under it.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_envelope_reads/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const WAIT_SECONDS: float = 5.0
const SLACK: float = 1.0

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SIZES[0]
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
	Settings.set_value("reduced_motion", false)
	Settings.set_value(TextSize.SETTING, 0)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.get("_loop")


## Opens kind from the state store, or the parcel from the black market, and returns it.
func _opened(kind: String) -> EnvelopeOverlay:
	_loop().state.coupons = 60
	_app.controller.reseal_book()
	_loop().shop.envelopes.clear()
	_loop().market.envelopes.clear()
	var counter: EnvelopeCounter = _loop().shop.envelopes
	if kind == "parcel":
		counter = _loop().market.envelopes
	counter.set("_stock", [kind] as Array[String])
	var store: StoreScreen = _app.show_screen("black_market" if kind == "parcel" else "store", true)
	await await_idle_frame()
	var stall: EnvelopeStall = store.get("_envelope_stall")
	stall.panel(0).buy.pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	return stall.overlay()


func test_a_reason_every_paper_shares_is_said_once() -> void:
	Settings.set_value("reduced_motion", true)
	_loop().state.inventory.consumables.assign(["grain_loan", "appeal"])
	var overlay: EnvelopeOverlay = await _opened("campaign_envelope")
	var why: String = tr("envelope.refused.campaigns_full")
	assert_str(overlay.asked()).is_equal(tr("envelope.refused.all").format({"why": why}))
	for paper: ChoicePaper in overlay.papers():
		assert_bool(paper.is_takeable()).is_false()
		assert_str(paper.caption()).is_equal(tr("envelope.refused.short"))
	var detail: EnvelopeDetail = overlay.get("_detail")
	var rule: RichTextLabel = detail.get("_rule")
	assert_str(rule.get_parsed_text()).not_contains(why)
	overlay.nothing_button().pressed.emit()


func test_a_reason_one_paper_alone_has_is_said_on_it() -> void:
	Settings.set_value("reduced_motion", true)
	var overlay: EnvelopeOverlay = await _opened("campaign_envelope")
	assert_str(overlay.asked()).is_equal(tr("envelope.choose"))
	overlay.nothing_button().pressed.emit()


func test_the_column_keeps_clear_of_the_screen_edges() -> void:
	Settings.set_value("reduced_motion", true)
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			for full: bool in [false, true]:
				var held: Array[String] = []
				if full:
					held.assign(["grain_loan", "appeal"])
				_loop().state.inventory.consumables.assign(held)
				for kind: String in ["directive_envelope", "campaign_envelope", "parcel"]:
					var overlay: EnvelopeOverlay = await _opened(kind)
					var where: String = "%s %s text %d full %s" % [kind, screen_size, level, full]
					var screen: Rect2 = get_tree().root.get_visible_rect()
					var heading: Rect2 = overlay.blocks()["heading"].get_global_rect()
					var button: Rect2 = overlay.nothing_button().get_global_rect()
					(
						assert_float(heading.position.y - screen.position.y)
						. override_failure_message(where + " top")
						. is_greater_equal(EnvelopeOverlay.EDGE - SLACK)
					)
					(
						assert_float(screen.end.y - button.end.y)
						. override_failure_message(where + " bottom")
						. is_greater_equal(EnvelopeOverlay.EDGE - SLACK)
					)
					overlay.nothing_button().pressed.emit()
					await await_idle_frame()


func test_a_kept_seal_lies_off_its_caption_and_take_nothing_goes() -> void:
	for kind: String in ["parcel", "directive_envelope"]:
		var overlay: EnvelopeOverlay = await _opened(kind)
		var waited: float = 0.0
		while overlay.is_busy() and waited < WAIT_SECONDS:
			await get_tree().process_frame
			waited += get_process_delta_time()
		var index: int = 0
		while not overlay.papers()[index].is_takeable():
			index += 1
		var paper: ChoicePaper = overlay.papers()[index]
		paper.keep.pressed.emit()
		await get_tree().create_timer(0.45).timeout
		assert_bool(overlay.seal().visible).override_failure_message(kind).is_true()
		var seal: Rect2 = overlay.seal().get_global_rect().grow(-SLACK)
		if paper.caption_strip().is_visible_in_tree():
			var strip: Rect2 = paper.caption_strip().get_global_rect()
			(
				assert_bool(seal.intersects(strip))
				. override_failure_message("%s: seal %s on caption %s" % [kind, seal, strip])
				. is_false()
			)
		assert_float(overlay.nothing_button().modulate.a).override_failure_message(kind).is_less(
			0.05
		)
		assert_bool(overlay.nothing_button().disabled).is_true()
		waited = 0.0
		while is_instance_valid(overlay) and waited < WAIT_SECONDS:
			await get_tree().process_frame
			waited += get_process_delta_time()

extends GdUnitTestSuite
## An open envelope reads once and keeps clear: when no paper can be kept for one shared
## reason, the reason is said once under the envelope's name, each paper says only that it
## cannot be kept, and the explanation does not say it again; the column keeps a margin
## from the screen's top and bottom at every text size; and a kept paper's seal lies off
## its caption, with Take Nothing gone from under it.

const SEED: int = 4242
const WAIT_SECONDS: float = 5.0

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = ClipCheck.SIZES[0]
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", false)
	Settings.set_value(TextSize.SETTING, 0)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Opens kind from the state store, or the parcel from the black market, and returns it.
func _opened(kind: String) -> EnvelopeOverlay:
	_loop().state.coupons = 60
	_app.controller.reseal_book()
	_loop().visit.shop.envelopes.clear()
	_loop().visit.market.envelopes.clear()
	var counter: EnvelopeCounter = _loop().visit.shop.envelopes
	if kind == "parcel":
		counter = _loop().visit.market.envelopes
	counter.stock_with([kind] as Array[String])
	var store: StoreScreen = _app.show_screen(
		ScreenId.BLACK_MARKET if kind == "parcel" else ScreenId.STORE, true
	)
	await await_idle_frame()
	var stall: EnvelopeStall = store.envelope_stall
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
	var detail: EnvelopeDetail = overlay.detail
	var rule: RichTextLabel = detail.rule_text
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
		for screen_size: Vector2i in ClipCheck.SIZES:
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
						. is_greater_equal(EnvelopeOverlay.EDGE - ClipCheck.SLACK)
					)
					(
						assert_float(screen.end.y - button.end.y)
						. override_failure_message(where + " bottom")
						. is_greater_equal(EnvelopeOverlay.EDGE - ClipCheck.SLACK)
					)
					overlay.nothing_button().pressed.emit()
					await await_idle_frame()


func test_a_kept_seal_lies_off_its_caption_and_take_nothing_goes() -> void:
	for kind: String in ["parcel", "directive_envelope"]:
		var overlay: EnvelopeOverlay = await _opened(kind)
		await TestWait.until(
			self,
			func() -> bool: return not overlay.is_busy(),
			"the envelope to settle",
			WAIT_SECONDS
		)
		var index: int = 0
		while not overlay.papers()[index].is_takeable():
			index += 1
		var paper: ChoicePaper = overlay.papers()[index]
		paper.keep.pressed.emit()
		var sealed: Callable = func() -> bool: return overlay.seal().visible
		await TestWait.until(self, sealed, "the seal on the %s" % kind, WAIT_SECONDS)
		var seal: Rect2 = overlay.seal().get_global_rect().grow(-ClipCheck.SLACK)
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
		await TestWait.until(
			self,
			func() -> bool: return not is_instance_valid(overlay),
			"the envelope to close",
			WAIT_SECONDS
		)

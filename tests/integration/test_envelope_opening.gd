extends GdUnitTestSuite
## The envelope's opening act can be ended: an envelope is opened many times a
## run, so a click lays its papers out at once, and that click chooses nothing.

const SEED: int = 4242

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	Settings.set_value("reduced_motion", false)
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	_loop().state.coupons = 60
	_app.controller.reseal_book()


func after_test() -> void:
	Settings.set_value("reduced_motion", SettingsStore.DEFAULTS.get("reduced_motion"))
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _open() -> StoreScreen:
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func _bought(store: StoreScreen) -> EnvelopeOverlay:
	var stall: EnvelopeStall = store.envelope_stall
	stall.panel(0).buy.pressed.emit()
	return stall.overlay()


func test_a_click_ends_the_opening_and_chooses_nothing() -> void:
	var store: StoreScreen = await _open()
	var overlay: EnvelopeOverlay = _bought(store)
	await TestWait.until(self, overlay.is_busy, "the opening to begin")
	var commands: int = _loop().record.commands.size()
	var paper: ChoicePaper = overlay.papers()[0]
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = paper.keep.get_global_rect().get_center()
	click.global_position = click.position
	get_viewport().push_input(click)
	assert_bool(overlay.is_busy()).is_false()
	assert_bool(overlay.figure().visible).is_false()
	for laid: ChoicePaper in overlay.papers():
		assert_vector(laid.position).is_equal(Vector2.ZERO)
		assert_vector(laid.scale).is_equal(Vector2.ONE)
		assert_float(laid.rotation).is_equal(0.0)
	# Nothing of the act runs on after it: the papers stay where they were laid.
	# Timed: that nothing moves is seen only over the time the act would have run.
	await get_tree().create_timer(EnvelopeOpening.OPEN_TIME + EnvelopeOpening.FAN_TIME).timeout
	assert_bool(is_instance_valid(overlay)).is_true()
	assert_vector(paper.position).is_equal(Vector2.ZERO)
	assert_int(_loop().record.commands.size()).is_equal(commands)

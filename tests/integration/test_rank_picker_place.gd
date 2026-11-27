extends GdUnitTestSuite
## The rank picker stands beside the Cadre it asks about, never over it, and the card
## stays above the dim, at both window sizes and every text size; inside its paper the
## tickets keep one padding from the border and a clear gap under the prompt.

const SEED: int = 4242
## Inside the paper's printed border, which ends 17 px in.
const BORDER: float = 17.0

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_the_picker_stands_beside_its_card_with_even_padding() -> void:
	# Measured at rest: the strip's entrance scales it in.
	Settings.set_value("reduced_motion", true)
	var loop: RunLoop = _app.controller.run_loop()
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			for slot: int in 3:
				get_tree().root.size = screen_size
				loop.state.coupons = 40
				_app.controller.reseal_book()
				var offered: Array[String] = ["steel_target", "last_sheaf", "loudspeaker"]
				offered[slot] = "rehabilitation"
				loop.visit.market.stock_with(offered, loop.visit.market.directive_stock())
				var market: StoreScreen = _app.show_screen(App.BLACK_MARKET, true)
				await await_idle_frame()
				var market_cadres: CadreCounter = market.cadres
				var counter: HBoxContainer = market_cadres.row
				var card: Control = counter.get_child(slot) as Control
				var buy: Button = card.find_children("*", "Button", true, false)[0]
				buy.pressed.emit()
				await await_idle_frame()
				var picker: RankPicker = market_cadres.picker
				var where: String = "%s text %d slot %d" % [screen_size, level, slot]
				_check(picker, card, where)
				picker.close()
				assert_int(card.z_index).override_failure_message(where).is_equal(0)


func _check(picker: RankPicker, card: Control, where: String) -> void:
	assert_bool(picker.is_open()).override_failure_message(where).is_true()
	var box: Rect2 = picker.get_global_rect()
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	assert_bool(screen.encloses(box)).override_failure_message("%s %s" % [where, box]).is_true()
	var over: bool = box.grow(-ClipCheck.SLACK).intersects(card.get_global_rect())
	assert_bool(over).override_failure_message("%s: over its card" % where).is_false()
	assert_int(card.z_index).override_failure_message(where).is_greater(picker.scrim().z_index)
	var chips: Array[RankChip] = picker.chips()
	var first: Rect2 = chips[0].get_global_rect()
	var last: Rect2 = chips[-1].get_global_rect()
	var inside: float = RankPicker.PADDING - BORDER - ClipCheck.SLACK
	(
		assert_float(first.position.x - box.position.x - BORDER)
		. override_failure_message(where + " left")
		. is_greater_equal(inside)
	)
	(
		assert_float(box.end.x - last.end.x - BORDER)
		. override_failure_message(where + " right")
		. is_greater_equal(inside)
	)
	var prompt: Label = picker.prompt_label
	var gap: float = first.position.y - RankChip.LIFT - prompt.get_global_rect().end.y
	assert_float(gap).override_failure_message(where + " prompt").is_greater_equal(
		RankPicker.SPACING - ClipCheck.SLACK
	)

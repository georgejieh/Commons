extends GdUnitTestSuite
## The Skip question stands over the whole screen as the game makes it: its dim covers the
## screen and its sheet stands in the middle, on the arrival page and over the table
## mid-arrival, at 1920x1080 and 1280x800.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SETTINGS: Array[String] = ["content_note_seen", "reduced_motion"]
const SLACK: float = 1.5

static var _save_path: String = TestFolder.of("test_skip_confirm_layout") + "run.json"

var _app: DemoApp = null
var _was_size: Vector2i
var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	_was_size = get_tree().root.size
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("content_note_seen", true)
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func after_test() -> void:
	get_tree().root.size = _was_size
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _launch(screen_size: Vector2i) -> void:
	if _app != null and is_instance_valid(_app):
		_app.free()
	get_tree().root.size = screen_size
	_app = AppKit.make(self)
	await await_idle_frame()


func test_the_question_on_the_arrival_page_covers_the_screen() -> void:
	for screen_size: Vector2i in SIZES:
		await _launch(screen_size)
		# The surname page's default with Enter, then the arrival page, as on a first launch.
		assert_str(_app.switcher.current_id()).is_equal("surname")
		await TestInput.tap_key(self, KEY_ENTER)
		await await_idle_frame()
		var page: ArrivalScreen = _app.switcher.current()
		page.skip_button().pressed.emit()
		await await_idle_frame()
		_assert_covers(page.confirm(), screen_size, "page at %s" % screen_size)


func test_the_question_over_the_table_covers_the_screen() -> void:
	for screen_size: Vector2i in SIZES:
		await _launch(screen_size)
		_app.arrival.start()
		await await_idle_frame()
		var layer: TutorialLayer = _app.arrival.layer
		layer.skip_button().pressed.emit()
		await await_idle_frame()
		_assert_covers(layer.confirm(), screen_size, "table at %s" % screen_size)


func _assert_covers(confirm: SkipConfirm, screen_size: Vector2i, where: String) -> void:
	# The window's size, as the stretch to the base resolution shows it.
	var screen: Rect2 = confirm.get_viewport_rect()
	assert_float(screen.size.aspect()).is_equal_approx(float(screen_size.aspect()), 0.01)
	assert_bool(confirm.is_asking()).override_failure_message(where).is_true()
	var dim: ColorRect = confirm.get_child(0) as ColorRect
	_assert_rect(dim.get_global_rect(), screen, where + " dim")
	var sheets: Array[Node] = confirm.find_children("*", "PanelContainer", true, false)
	assert_int(sheets.size()).override_failure_message(where).is_equal(1)
	var sheet: Rect2 = (sheets[0] as Control).get_global_rect()
	assert_bool(sheet.has_area()).override_failure_message(where + " sheet size").is_true()
	var off: Vector2 = (sheet.get_center() - screen.get_center()).abs()
	(
		assert_bool(off.x <= SLACK and off.y <= SLACK)
		. override_failure_message("%s sheet at %s, off the middle by %s" % [where, sheet, off])
		. is_true()
	)


func _assert_rect(found: Rect2, wanted: Rect2, where: String) -> void:
	var close: bool = (
		found.position.distance_to(wanted.position) <= SLACK
		and found.size.distance_to(wanted.size) <= SLACK
	)
	assert_bool(close).override_failure_message("%s is %s" % [where, found]).is_true()

extends GdUnitTestSuite
## Every page with a Back button goes back on Cancel (Escape, or B on a pad), as Back does:
## the title's settings, collection, village history and run setup, the dossier and the
## last round's summary, and the black market back to the state store. The state store's
## Leave ends the visit, so Cancel there leaves the page where it is.

const SEED: int = 4242
const TITLE_PAGES: Array[String] = [
	ScreenId.SETTINGS, ScreenId.COLLECTION, ScreenId.VILLAGE_HISTORY, ScreenId.RUN_SETUP
]
const RUN_PAGES: Array[String] = [ScreenId.DOSSIER, ScreenId.ROUND_SUMMARY]

static var _save_path: String = TestFolder.of("test_cancel_goes_back") + "run.json"

var _app: App


func before_test() -> void:
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	_app = AppKit.make(self)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func test_cancel_goes_back_from_the_titles_pages() -> void:
	for page: String in TITLE_PAGES:
		await _check_back(page, ScreenId.TITLE)


func test_cancel_goes_back_from_the_runs_records() -> void:
	_app.new_run(SEED)
	for page: String in RUN_PAGES:
		await _check_back(page, ScreenId.TITLE)


func test_cancel_goes_back_from_the_black_market_and_not_from_the_store() -> void:
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	await _check_back(ScreenId.BLACK_MARKET, ScreenId.STORE)
	await _cancel()
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.STORE)


## Opens page over from, presses Cancel, and checks that it went back.
func _check_back(page: String, from: String) -> void:
	_app.show_screen(from, true)
	await await_idle_frame()
	_app.show_screen(page)
	await await_idle_frame()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(page)
	await _cancel()
	assert_str(_app.switcher.current_id()).override_failure_message(page).is_equal(from)


func _cancel() -> void:
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = "ui_cancel"
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await await_idle_frame()
	await await_idle_frame()

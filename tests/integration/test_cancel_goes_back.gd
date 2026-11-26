extends GdUnitTestSuite
## Every page with a Back button goes back on Cancel (Escape, or B on a pad), as Back does:
## the title's settings, collection, village history and run setup, the dossier and the
## last round's summary, and the black market back to the state store. The state store's
## Leave ends the visit, so Cancel there leaves the page where it is.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_cancel_goes_back/run.json"
const TITLE_PAGES: Array[String] = ["settings", "collection", "village_history", "run_setup"]
const RUN_PAGES: Array[String] = ["dossier", "round_summary"]

var _app: DemoApp


func before_test() -> void:
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	_app = auto_free((load("res://ui/main.tscn") as PackedScene).instantiate())
	add_child(_app)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func test_cancel_goes_back_from_the_titles_pages() -> void:
	for page: String in TITLE_PAGES:
		await _check_back(page, "title")


func test_cancel_goes_back_from_the_runs_records() -> void:
	_app.new_run(SEED)
	for page: String in RUN_PAGES:
		await _check_back(page, "title")


func test_cancel_goes_back_from_the_black_market_and_not_from_the_store() -> void:
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	await _check_back("black_market", "store")
	await _cancel()
	assert_str(_app.switcher.current_id()).is_equal("store")


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

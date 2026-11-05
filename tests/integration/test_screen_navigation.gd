extends GdUnitTestSuite
## Every screen is reachable through the buttons a player presses (P3B.9), and going
## back from a screen opened over the run never changes the run.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_screen_navigation/run.json"

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Saves.run_service().delete()


func test_the_title_reaches_setup_collection_and_history() -> void:
	_app.show_screen("title", true)
	await await_idle_frame()
	for pair: Array in [
		["title.collection", "collection"],
		["title.history", "village_history"],
		["title.new_run", "run_setup"],
	]:
		_press(pair[0])
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(pair[1])
		_app.back()
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal("title")


func test_run_setup_starts_a_run_at_the_set_intro() -> void:
	_app.show_screen("title", true)
	await await_idle_frame()
	_press("title.new_run")
	await await_idle_frame()
	_press("setup.start")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("set_intro")
	assert_bool(_app.controller.has_run()).is_true()


func test_the_table_menu_reaches_the_dossier_and_last_round_and_back() -> void:
	_app.new_run(SEED)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	var before: Dictionary = _app.controller.state_copy().to_dict()
	for pair: Array in [["dossier.open", "dossier"], ["pause.last_round", "round_summary"]]:
		table = _app.switcher.current()
		table.call("_open_pause")
		_press(pair[0])
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(pair[1])
		_app.back()
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal("table")
		assert_dict(_app.controller.state_copy().to_dict()).is_equal(before)


func test_the_store_reaches_the_black_market_and_back() -> void:
	_app.new_run(SEED)
	_app.show_screen("set_intro", true)
	_app.show_screen("store")
	await await_idle_frame()
	var before: Dictionary = _app.controller.state_copy().to_dict()
	_press("market.open")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("black_market")
	_press("market.back")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("store")
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(before)


## Screens whose systems arrive in Phase 4 open over the table and go back to it.
func test_phase_4_screens_open_over_the_run_and_go_back() -> void:
	_app.new_run(SEED)
	_app.show_screen("table", true)
	await await_idle_frame()
	var before: Dictionary = _app.controller.state_copy().to_dict()
	for screen_id: String in ["plot_swap", "reeducation"]:
		_app.show_screen(screen_id)
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(screen_id)
		_press_first()
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal("table")
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(before)
	_app.show_screen("ending", true)
	await await_idle_frame()
	_press("end.to_title")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("title")


func test_a_finished_round_shows_in_the_last_round_summary() -> void:
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	var rounds_before: int = _app.controller.state_copy().round_index
	for _step: int in 400:
		if _app.controller.state_copy().round_index > rounds_before:
			break
		if not driver.act(_app.controller):
			break
	var last: Dictionary = RoundSummaryScreen.last_round(_app.controller.set_events())
	assert_bool(last.has("won")).is_true()
	assert_bool(last.has("score")).is_true()


func _press(key: String) -> void:
	var button: Button = _find_button(_app, tr(key))
	assert_object(button).override_failure_message("no button " + key).is_not_null()
	if button != null:
		button.pressed.emit()


func _press_first() -> void:
	var button: Button = _find_button(_app.switcher.current(), "")
	assert_object(button).is_not_null()
	button.pressed.emit()


## The first visible button with this text, or the first visible one when text is empty.
func _find_button(node: Node, text: String) -> Button:
	var button: Button = node as Button
	if button != null and button.is_visible_in_tree() and (text.is_empty() or button.text == text):
		return button
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null

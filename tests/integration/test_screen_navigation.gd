extends GdUnitTestSuite
## Every screen is reachable through the buttons a player presses, and going
## back from a screen opened over the run never changes the run.

const SEED: int = 4301

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	Saves.run_service().delete()


func test_the_title_reaches_setup_collection_and_history() -> void:
	_app.show_screen(App.TITLE, true)
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
		assert_str(_app.switcher.current_id()).is_equal(App.TITLE)


func test_run_setup_starts_a_run_at_the_set_intro() -> void:
	_app.show_screen(App.TITLE, true)
	await await_idle_frame()
	_press("title.new_run")
	await await_idle_frame()
	_press("setup.start")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(App.SET_INTRO)
	assert_bool(_app.controller.has_run()).is_true()


func test_the_table_menu_reaches_the_dossier_and_last_round_and_back() -> void:
	_app.new_run(SEED)
	var table: TableScreen = _app.show_screen(App.TABLE, true)
	await await_idle_frame()
	table.skip_events()
	var was: Dictionary = _app.controller.state_copy().to_dict()
	for pair: Array in [["dossier.open", "dossier"], ["pause.last_round", "round_summary"]]:
		table = _app.switcher.current()
		table.hud.menu.pressed.emit()
		_press(pair[0])
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(pair[1])
		_app.back()
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(App.TABLE)
		assert_dict(_app.controller.state_copy().to_dict()).is_equal(was)


func test_the_store_reaches_the_black_market_and_back() -> void:
	_app.new_run(SEED)
	_app.show_screen(App.SET_INTRO, true)
	_app.show_screen(App.STORE)
	await await_idle_frame()
	var was: Dictionary = _app.controller.state_copy().to_dict()
	_press("market.open")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(App.BLACK_MARKET)
	_press("market.back")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(App.STORE)
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(was)


## The reeducation screen opens over the table and goes back to it.
func test_reeducation_opens_over_the_table_and_goes_back() -> void:
	_app.new_run(SEED)
	_app.show_screen(App.TABLE, true)
	await await_idle_frame()
	var was: Dictionary = _app.controller.state_copy().to_dict()
	for screen_id: String in ["reeducation"]:
		_app.show_screen(screen_id)
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(screen_id)
		_press_first()
		await await_idle_frame()
		assert_str(_app.switcher.current_id()).is_equal(App.TABLE)
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(was)
	_app.show_screen(App.ENDING, true)
	await await_idle_frame()
	_press("end.to_title")
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(App.TITLE)


func test_a_finished_round_shows_in_the_last_round_summary() -> void:
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	var rounds_before: int = _app.controller.state_copy().round_index
	for _step: int in 400:
		if _app.controller.state_copy().round_index > rounds_before:
			break
		if not driver.act(_app.controller):
			break
	var last: RoundResult = RoundResult.last(_app.controller.set_events())
	assert_object(last).override_failure_message("no round finished").is_not_null()


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


func test_last_round_reports_exact_values_and_keeps_them() -> void:
	var events: Array[RunEvent] = [
		RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, 1)),
		RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 2)),
		RunEvent.new(RunEvent.Type.ROUND_SCORED, 0, 0, 120.0),
		RunEvent.new(RunEvent.Type.SHARE_PAID, 0, 30),
		RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, 0)),
	]
	var last: RoundResult = RoundResult.last(events)
	assert_bool(last.won).is_true()
	assert_float(last.score).is_equal(120.0)
	assert_int(last.share).is_equal(30)
	events.append(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 1)))
	var lost: RoundResult = RoundResult.last(events)
	assert_bool(lost.won).is_false()


## A run saved while its plot swap waits continues at the table, which opens the swap's
## sheet over itself (ADR 0038): there is no swap screen to land on.
func test_a_waiting_swap_continues_at_the_table() -> void:
	_app.new_run(SEED)
	assert_str(_app.screen_for(RunController.AWAIT_SWAP)).is_equal(App.TABLE)

extends GdUnitTestSuite
## ADR 0025 in the app: New Run starts the full run unless the app runs as --demo; the
## title offers Continue only for a run that loads; Abandon asks first, with the focus on
## Keep playing, clears the save and records nothing; the ending's way home clears the
## save; and a Quota's end that took a family says so in one plain line. ADR 0031: the
## summary warns on the last free Quota without the landlord's seat and names the Famine
## each later one cost.

const SEED: int = 7720

static var _save_path: String = TestFolder.of("test_full_run_ui") + "run.json"

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _button(node: Node, text: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


func _title_has_continue() -> bool:
	_app.show_screen(ScreenId.TITLE, true)
	return _button(_app.switcher.current(), tr("title.continue")) != null


func test_new_run_starts_the_full_run_and_the_demo_under_its_flag() -> void:
	_app.demo = false
	_app.show_screen(ScreenId.RUN_SETUP, true)
	_press(tr("setup.start"))
	assert_bool(_app.controller.seats.has_village()).is_true()
	assert_bool(_app.controller.state_copy().identity.is_full()).is_true()
	assert_int(_app.controller.state_copy().coupons).is_equal(4)
	_app.demo = true
	_app.show_screen(ScreenId.RUN_SETUP, true)
	_press(tr("setup.start"))
	assert_bool(_app.controller.seats.has_village()).is_false()
	assert_bool(_app.controller.state_copy().identity.is_full()).is_false()


func test_continue_shows_only_for_a_run_that_loads() -> void:
	assert_bool(_title_has_continue()).is_false()
	_app.new_run(SEED, true)
	assert_bool(_title_has_continue()).is_true()
	_press(tr("title.continue"))
	assert_bool(_app.controller.seats.has_village()).is_true()
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.TABLE)
	# A save and backup that are both damaged offer nothing to continue.
	for path: String in [_save_path, _save_path + SaveService.BACKUP_SUFFIX]:
		FileAccess.open(path, FileAccess.WRITE).store_string("{broken")
	assert_bool(_title_has_continue()).is_false()


func test_continue_picks_up_a_demo_save_as_the_demo() -> void:
	_app.new_run(SEED)
	assert_bool(_title_has_continue()).is_true()
	_press(tr("title.continue"))
	assert_bool(_app.controller.has_run()).is_true()
	assert_bool(_app.controller.seats.has_village()).is_false()


func test_abandon_asks_first_then_clears_the_run_and_records_nothing() -> void:
	_app.new_run(SEED, true)
	_app.show_screen(ScreenId.SET_INTRO, true)
	await await_idle_frame()
	var menu: PauseMenu = _app.menu
	menu.open()
	_press(tr("menu.abandon"))
	await await_idle_frame()
	assert_bool(menu.is_confirming()).is_true()
	assert_str(tr("menu.abandon.confirm")).is_equal("Abandon this run? It will not be recorded.")
	assert_object(get_viewport().gui_get_focus_owner()).is_same(menu.keep_button())
	# Cancel goes back to the menu; Keep playing closes it with the run kept.
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	get_tree().root.push_input(cancel)
	await await_idle_frame()
	assert_bool(menu.visible).is_true()
	assert_bool(menu.is_confirming()).is_false()
	_press(tr("menu.abandon"))
	await await_idle_frame()
	menu.keep_button().pressed.emit()
	assert_bool(menu.visible).is_false()
	assert_bool(FileAccess.file_exists(_save_path)).is_true()
	menu.open()
	_press(tr("menu.abandon"))
	await await_idle_frame()
	var was: ProfileData = Profile.read(Saves.profile_service())
	menu.abandon_button().pressed.emit()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.TITLE)
	assert_bool(FileAccess.file_exists(_save_path)).is_false()
	var now: ProfileData = Profile.read(Saves.profile_service())
	assert_array(now.history).is_empty()
	assert_int(now.finished_runs).is_equal(was.finished_runs)
	assert_bool(_title_has_continue()).is_false()


func test_the_table_menu_abandons_too() -> void:
	_app.new_run(SEED, true)
	var table: TableScreen = _app.show_screen(ScreenId.TABLE, true)
	await await_idle_frame()
	table.hud.menu.pressed.emit()
	var pause: PauseMenu = table.pause
	_press(tr("menu.abandon"))
	await await_idle_frame()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(pause.keep_button())
	pause.abandon_button().pressed.emit()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.TITLE)
	assert_bool(FileAccess.file_exists(_save_path)).is_false()


func test_the_endings_way_home_clears_the_run_save() -> void:
	var state: RunState = RunState.new(SEED)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.year_rounds = 4
	state.identity.kind = RunIdentity.Kind.FULL
	Roster.start(state, RunDefaults.VILLAGE, [])
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	Saves.run_service().save(record.to_dict())
	_app.resume_to_screen()
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.ENDING)
	assert_int(Profile.read(Saves.profile_service()).history.size()).is_equal(1)
	var screen: EndingScreen = _app.switcher.current()
	await await_idle_frame()
	screen.home_button().pressed.emit()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal(ScreenId.TITLE)
	assert_bool(FileAccess.file_exists(_save_path)).is_false()
	assert_int(Profile.read(Saves.profile_service()).history.size()).is_equal(1)


## A full run's Quota ended in high Famine: the summary names the family that starved in
## one line, and the dossier shows its seat no more.
func test_the_summary_names_the_family_that_starved() -> void:
	_app.new_run(SEED, true)
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.famine = RunDefaults.METERS.famine.high
	# The Quota met already, so it closes at its first round and no miss moves Famine.
	loop.state.set_progress = loop.target()
	_app.controller.reseal_book()
	var script: ControllerScript = ControllerScript.new()
	while script.act(_app.controller):
		pass
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SET_OVER)
	var dead: String = ""
	var seat: int = 0
	for event: RunEvent in _app.controller.set_events():
		if event.type == RunEvent.Type.STARVED:
			dead = event.text
			seat = event.seat
	assert_str(dead).is_not_empty()
	var summary: SetSummaryScreen = _app.show_screen(ScreenId.SET_SUMMARY, true)
	var family: String = tr(_app.controller.seats.family_name_key(dead))
	var line: String = "The %s household did not come to the Commons." % family
	assert_array(summary.fate_lines()).contains_exactly([line])
	assert_bool(_app.controller.seats.seat_gone(seat)).is_true()
	var dossier: DossierScreen = _app.show_screen(ScreenId.DOSSIER, true)
	assert_int(dossier.entries(seat).size()).is_equal(0)
	assert_int(dossier.entries(3 - seat).size()).is_greater(0)


## Plays the first Quota met in its first round, the player passing every bid, from
## seatless Quotas already in a row. Returns the summary, or null when the player held the
## seat after all.
func _seatless_summary(seatless: int) -> SetSummaryScreen:
	_app.new_run(SEED, true)
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.seatless_sets = seatless
	# The Quota met already, so it closes at its first round.
	loop.state.set_progress = loop.target()
	_app.controller.reseal_book()
	var script: ControllerScript = ControllerScript.new()
	while true:
		if _app.controller.awaiting() == RunController.AWAIT_BID:
			if _app.controller.bid(false) != RunController.OK:
				break
		elif not script.act(_app.controller):
			break
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SET_OVER)
	if YearClass.held_seat(_app.controller.set_events(), RunLoop.PLAYER):
		return null
	return _app.show_screen(ScreenId.SET_SUMMARY, true)


## ADR 0031: the last free Quota warns that the next one without the seat costs.
func test_the_summary_warns_on_the_last_free_quota() -> void:
	var grace: int = RunDefaults.PARAMS.seat_grace_sets
	var summary: SetSummaryScreen = _seatless_summary(grace - 1)
	assert_object(summary).is_not_null()
	if summary == null:
		return
	var line: String = (
		"%d Quotas in a row without the landlord's seat. Hold it in one round of the next " % grace
		+ "Quota, or Famine rises."
	)
	assert_array(summary.seat_lines()).contains_exactly([line])


## ADR 0031: a Quota past the grace says how many in a row, and the Famine they added.
func test_the_summary_names_the_famine_the_unheld_seat_cost() -> void:
	var grace: int = RunDefaults.PARAMS.seat_grace_sets
	var summary: SetSummaryScreen = _seatless_summary(grace + 1)
	assert_object(summary).is_not_null()
	if summary == null:
		return
	var rise: int = 2 * RunDefaults.METERS.source(RunMeters.STOOD_BY).amount
	var line: String = (
		"Famine rose by %d for %d Quotas in a row without the landlord's seat." % [rise, grace + 2]
	)
	assert_array(summary.seat_lines()).contains_exactly([line])


## Inside the grace the summary says nothing of the seat.
func test_the_summary_is_silent_inside_the_grace() -> void:
	var summary: SetSummaryScreen = _seatless_summary(0)
	assert_object(summary).is_not_null()
	if summary == null:
		return
	assert_array(summary.seat_lines()).is_empty()


func _press(text: String) -> void:
	var button: Button = _button(_app, text)
	assert_object(button).override_failure_message("no button " + text).is_not_null()
	if button != null:
		button.pressed.emit()

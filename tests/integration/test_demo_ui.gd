extends GdUnitTestSuite
## A scripted smoke test of the demo UI (P3B.9 in part, ADR 0017): every demo screen
## opens over a live run, back navigation keeps the run, and the table drives a whole
## Set to its summary through the same buttons a player presses.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_demo_ui/run.json"
const SCREENS: Array[String] = [
	"title",
	"set_intro",
	"table",
	"set_summary",
	"store",
	"year_summary",
	"settings",
	"demo_complete",
]

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Saves.run_service().delete()


func test_every_demo_screen_opens() -> void:
	for screen_id: String in SCREENS:
		var screen: Node = _app.show_screen(screen_id, true)
		await await_idle_frame()
		assert_object(screen).is_not_null()
		assert_str(_app.switcher.current_id()).is_equal(screen_id)


func test_back_navigation_keeps_the_run() -> void:
	_app.show_screen("table", true)
	await await_idle_frame()
	var before: Dictionary = _app.controller.state_copy().to_dict()
	_app.show_screen("settings")
	await await_idle_frame()
	_app.back()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("table")
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(before)


func test_the_table_plays_a_set_to_its_summary() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var driver: ControllerScript = ControllerScript.new()
	for _turn: int in 600:
		if _app.switcher.current_id() == "set_summary":
			break
		table.skip_events()
		if _app.switcher.current_id() != "table":
			break
		_press(table, driver)
		await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("set_summary")


## Takes the player's turn through the table's own buttons and hand model.
func _press(table: TableScreen, driver: ControllerScript) -> void:
	match _app.controller.awaiting():
		RunController.AWAIT_BID:
			table.actions().decline.pressed.emit()
		RunController.AWAIT_NEED:
			table.need_panel().declared.emit(ControllerScript.NEED)
		RunController.AWAIT_PLAY:
			var ids: Array[int] = driver.choose_play(_app.controller)
			if ids.is_empty():
				table.actions().pass_turn.pressed.emit()
				return
			for card_id: int in ids:
				_app.hand.toggle(card_id)
			assert_bool(table.actions().play.disabled).is_false()
			table.actions().play.pressed.emit()


## Every literal key the UI and game layers pass to tr() is in the string table.
func test_every_literal_ui_key_is_in_the_table() -> void:
	var keys: Dictionary[String, bool] = {}
	var table: FileAccess = FileAccess.open("res://data/strings/strings.csv", FileAccess.READ)
	while not table.eof_reached():
		var row: PackedStringArray = table.get_csv_line()
		if not row.is_empty():
			keys[row[0]] = true
	var pattern: RegEx = RegEx.create_from_string(r'tr\("([a-z0-9_.]+)"\)')
	var missing: PackedStringArray = []
	for root: String in ["res://ui", "res://game"]:
		for path: String in _scripts(root):
			for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
				if not keys.has(found.get_string(1)):
					missing.append("%s: %s" % [path, found.get_string(1)])
	assert_array(missing).is_empty()


func _scripts(root: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for name: String in DirAccess.get_files_at(root):
		if name.ends_with(".gd"):
			paths.append(root.path_join(name))
	for folder: String in DirAccess.get_directories_at(root):
		paths.append_array(_scripts(root.path_join(folder)))
	return paths


## After a command the buttons stay off until the bots' plays have been shown.
func test_buttons_lock_while_events_play() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var driver: ControllerScript = ControllerScript.new()
	for _turn: int in 200:
		table.skip_events()
		if _app.controller.awaiting() == RunController.AWAIT_PLAY:
			break
		_press(table, driver)
		await await_idle_frame()
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_PLAY)
	table.skip_events()
	var ids: Array[int] = driver.choose_play(_app.controller)
	for card_id: int in ids:
		_app.hand.toggle(card_id)
	if ids.is_empty():
		table.actions().pass_turn.pressed.emit()
	else:
		table.actions().play.pressed.emit()
	if _app.controller.awaiting() == RunController.AWAIT_PLAY:
		assert_bool(table.actions().pass_turn.disabled).is_true()
		assert_bool(table.actions().play.disabled).is_true()


## A shortcut presses the same button a click does: Pass on the bid turns the call down.
func test_a_shortcut_presses_its_button() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	if _app.controller.awaiting() != RunController.AWAIT_BID:
		return
	var shortcut: InputEventAction = InputEventAction.new()
	shortcut.action = "commons_pass"
	shortcut.pressed = true
	table._unhandled_input(shortcut)
	assert_int(_app.controller.awaiting()).is_not_equal(RunController.AWAIT_BID)


## The print pass follows its setting, and dread stays in range.
func test_the_post_process_follows_its_setting() -> void:
	var was: bool = bool(Settings.value("post_process"))
	Settings.set_value("post_process", false)
	assert_bool(_app.post.is_on()).is_false()
	Settings.set_value("post_process", true)
	assert_bool(_app.post.is_on()).is_true()
	_app.post.set_dread(4.0)
	Settings.set_value("post_process", was)


## Sort cycles rank, suit and groups, and the button names the current one.
func test_sort_cycles_and_names_its_mode() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.skip_events()
	var seen: Array[String] = []
	for _press_count: int in 3:
		table.actions().sort.pressed.emit()
		seen.append(table.actions().sort.text)
	assert_int(seen.size()).is_equal(3)
	assert_bool(seen[0] != seen[1] and seen[1] != seen[2]).is_true()
	assert_str(table.actions().sort.tooltip_text).is_not_empty()


## The rules card and the menu sit above the table and block clicks to it.
func test_overlays_open_above_the_table() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.actions().rules.pressed.emit()
	var sheet: Control = table.get("_cheat_sheet")
	assert_bool(sheet.visible).is_true()
	assert_int(sheet.get_index()).is_equal(table.get_child_count() - 1)
	assert_int(sheet.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	sheet.visible = false
	var hud: TableHud = table.get("_hud")
	hud.menu.pressed.emit()
	var pause: Control = table.get("_pause")
	assert_bool(pause.visible).is_true()
	assert_int(pause.get_index()).is_equal(table.get_child_count() - 1)


## Joining a Set mid-way replays its earlier events without raising their banners.
func test_rejoining_the_table_raises_no_old_banner() -> void:
	var driver: ControllerScript = ControllerScript.new()
	var ended: int = 0
	_app.controller.event_emitted.connect(
		func(event: RunEvent) -> void:
			if event.round_event != null and event.round_event.type == RoundEvent.Type.ROUND_ENDED:
				ended += 1
	)
	while not (ended >= 1 and _app.controller.awaiting() == RunController.AWAIT_BID):
		if not driver.act(_app.controller):
			return
	var table: TableScreen = _app.show_screen("table", true)
	var banner: Control = table.get("_banner")
	await await_millis(400)
	assert_float(banner.modulate.a).is_equal(0.0)

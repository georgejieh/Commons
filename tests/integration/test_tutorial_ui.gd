extends GdUnitTestSuite
## The arrival through the app (ADR 0026, P4.15): offered only with no profile save,
## after the content note; finished with the keyboard alone, its slip beside every step's
## target and never over it or the hand, in type 20 px or more, at 1920x1080 and
## 1280x800; finishing writes the profile's first save once, with the arrival seen, then
## run setup; skipping writes the same and goes to the title; quitting part-way writes
## nothing; a replay ends at the title and leaves the profile and a real run save as they
## were; a refused action pulses the slip.

const SAVE_PATH: String = "user://test_tutorial_ui/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SETTINGS: Array[String] = ["content_note_seen", "reduced_motion"]
const LEAST_TYPE: int = 20
const DARK_INK: float = 0.35
const SLACK: float = 1.5
## The longest any wait may take, in milliseconds: a board preview is a few seconds.
const WAIT_MSEC: int = 20000

var _app: DemoApp = null
var _was_size: Vector2i
var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	_was_size = get_tree().root.size
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("content_note_seen", true)
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func after_test() -> void:
	get_tree().root.size = _was_size
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _launch() -> DemoApp:
	if _app != null and is_instance_valid(_app):
		_app.free()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	await await_idle_frame()
	return _app


func _profile_bytes() -> String:
	var path: String = Saves.profile_service().path()
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func test_no_profile_offers_the_arrival_and_a_profile_the_title() -> void:
	await _launch()
	assert_str(_app.switcher.current_id()).is_equal("arrival")
	var page: ArrivalScreen = _app.switcher.current()
	assert_str(page.text()).starts_with("The cart leaves you at the brigade office.")
	assert_object(get_viewport().gui_get_focus_owner()).is_same(page.sit_in_button())
	ProfileSeen.mark(Saves.profile_service(), ProfileSeen.TUTORIAL)
	await _launch()
	assert_str(_app.switcher.current_id()).is_equal("title")


func test_the_content_note_leads_to_the_arrival_on_a_first_launch() -> void:
	Settings.set_value("content_note_seen", false)
	await _launch()
	assert_str(_app.switcher.current_id()).is_equal("content_note")
	for node: Node in _app.switcher.current().find_children("*", "Button", true, false):
		(node as Button).pressed.emit()
		break
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("arrival")
	assert_bool(ProfileSeen.exists(Saves.profile_service())).is_false()
	# The note's Continue saved the settings this test changed: put the saved file back.
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Settings.save()


func test_skip_asks_once_then_writes_the_profile_and_goes_to_the_title() -> void:
	await _launch()
	var page: ArrivalScreen = _app.switcher.current()
	page.skip_button().pressed.emit()
	assert_bool(page.confirm().is_asking()).is_true()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(page.confirm().stay_button())
	page.confirm().stay_button().pressed.emit()
	assert_str(_app.switcher.current_id()).is_equal("arrival")
	page.skip_button().pressed.emit()
	page.confirm().skip_button().pressed.emit()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("title")
	assert_array(Profile.read(Saves.profile_service()).seen).is_equal(["tutorial"])


func test_the_corner_skip_mid_arrival_writes_the_profile() -> void:
	await _launch()
	_app.arrival.start()
	await await_idle_frame()
	var layer: TutorialLayer = _app.arrival.layer
	assert_bool(layer.skip_button().is_visible_in_tree()).is_true()
	layer.skip_button().pressed.emit()
	layer.confirm().skip_button().pressed.emit()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("title")
	assert_bool(_app.arrival.is_running()).is_false()
	assert_array(Profile.read(Saves.profile_service()).seen).is_equal(["tutorial"])


func test_quitting_part_way_writes_nothing_and_offers_it_again() -> void:
	await _launch()
	_app.arrival.start()
	await _until_prompt()
	await _key(KEY_SPACE)
	_app.free()
	_app = null
	assert_bool(ProfileSeen.exists(Saves.profile_service())).is_false()
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_false()
	await _launch()
	assert_str(_app.switcher.current_id()).is_equal("arrival")


func test_a_refused_action_changes_nothing_and_marks_the_slip() -> void:
	await _launch()
	_app.arrival.start()
	await _until_prompt()
	var director: TutorialDirector = _app.arrival.director
	assert_int(director.index()).is_equal(0)
	# Calling is not what the first step asks for: Enter presses Call, which is refused.
	await _key(KEY_ENTER)
	assert_int(director.index()).is_equal(0)
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_BID)
	assert_bool(_app.arrival.layer.slip().is_alarmed()).is_true()


## The whole arrival with the keyboard alone at 1920x1080, then run setup and the
## profile's first save.
func test_the_keyboard_finishes_the_arrival_at_1080() -> void:
	get_tree().root.size = SIZES[0]
	await _launch()
	(_app.switcher.current() as ArrivalScreen).sit_in_button().grab_focus()
	await _key(KEY_ENTER)
	await _walk("1080")
	assert_str(_app.switcher.current_id()).is_equal("run_setup")
	var data: ProfileData = Profile.read(Saves.profile_service())
	assert_array(data.seen).is_equal(["tutorial"])
	var fresh: Dictionary = ProfileData.new().to_dict()
	fresh["seen"] = ["tutorial"]
	assert_dict(data.to_dict()).is_equal(fresh)
	assert_bool(FileAccess.file_exists(Saves.run_service().path())).is_false()


## Replayed from Settings at 1280x800 over a profile with history and a run in progress:
## it ends at the title, and the profile and the run save are byte for byte as they were.
func test_a_replay_at_800_leaves_the_profile_and_run_save_alone() -> void:
	get_tree().root.size = SIZES[1]
	var data: ProfileData = ProfileData.new()
	data.seen.append("tutorial")
	data.finished_runs = 2
	data.generation = 3
	data.corruption = 27.0
	data.memory.counts["wang"] = PackedFloat64Array([1.0, 2.0, 0.0, 0.0])
	Profile.write(Saves.profile_service(), data)
	await _launch()
	assert_bool(_app.new_run(4242, true)).is_true()
	var run_save: String = FileAccess.get_file_as_string(Saves.run_service().path())
	var profile: String = _profile_bytes()
	assert_str(run_save).is_not_empty()
	_app.show_screen("title", true)
	_app.show_screen("settings")
	await await_idle_frame()
	_app.arrival.start(true)
	await _walk("800")
	assert_str(_app.switcher.current_id()).is_equal("title")
	assert_str(FileAccess.get_file_as_string(Saves.run_service().path())).is_equal(run_save)
	assert_str(_profile_bytes()).is_equal(profile)


## Plays every step with the keys a player would press, checking the slip at each prompt.
func _walk(where: String) -> void:
	var guard: int = 0
	while _app.arrival.is_running() and guard < 40:
		guard += 1
		await _until_prompt()
		var director: TutorialDirector = _app.arrival.director
		if director == null:
			break
		var step: TutorialStep = director.step()
		await _check_slip("%s step %s" % [where, step.id])
		await _answer(step)
		await _until_moved(step)
	assert_bool(_app.arrival.is_running()).override_failure_message(where).is_false()


func _answer(step: TutorialStep) -> void:
	match step.action:
		TutorialStep.Action.BID_PASS, TutorialStep.Action.PASS:
			await _key(KEY_SPACE)
		TutorialStep.Action.BID_CALL, TutorialStep.Action.PLAY, TutorialStep.Action.NEED:
			await _key(KEY_ENTER)
		TutorialStep.Action.BUTTON:
			if step.button == "rules":
				await _key(KEY_R)
				await _until_line(step.then_key)
				await _check_slip("rules open")
				await _key(KEY_ESCAPE)
			elif not step.via.is_empty():
				await _key(KEY_ENTER)
				await _until_prompt()
				await _check_slip("black market")
				await _key(KEY_ENTER)
			else:
				await _key(KEY_ENTER)


## Waits until the step is done: the director moved past it, or the arrival ended.
func _until_moved(step: TutorialStep) -> void:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var director: TutorialDirector = _app.arrival.director
		if director == null or director.step() != step:
			return
		await await_idle_frame()


func _until_line(key: String) -> void:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if _app.arrival.layer.slip().line() == tr(key):
			return
		await await_idle_frame()


## Hurries the table and the follow-ups' beats until a prompt shows.
func _until_prompt() -> void:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		var director: TutorialDirector = _app.arrival.director
		if director == null or director.phase() == TutorialDirector.Phase.PROMPT:
			break
		if director.is_held():
			director.release()
		var table: TableScreen = _app.switcher.current() as TableScreen
		if table != null:
			table.skip_events()
		await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()


## The slip shows Wang's line beside the ringed target, clear of it and of the hand, on
## screen, in dark type 20 px or more.
func _check_slip(where: String) -> void:
	var layer: TutorialLayer = _app.arrival.layer
	var slip: TutorialSlip = layer.slip()
	assert_bool(slip.is_visible_in_tree()).override_failure_message(where).is_true()
	assert_int(slip.text_size()).override_failure_message(where).is_greater_equal(LEAST_TYPE)
	var label: Label = slip.find_children("*", "Label", true, false)[0]
	var ink: float = label.get_theme_color("font_color").get_luminance()
	assert_float(ink).override_failure_message(where).is_less(DARK_INK)
	var rect: Rect2 = slip.get_global_rect()
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	assert_bool(screen.encloses(rect)).override_failure_message(where).is_true()
	var target: Rect2 = layer.ring().ringed()
	assert_bool(target.has_area()).override_failure_message(where + " ring").is_true()
	assert_bool(rect.intersects(target)).override_failure_message(where + " target").is_false()
	var table: TableScreen = _app.switcher.current() as TableScreen
	if table != null:
		for hand: Rect2 in table.tutorial().tutorial_avoid():
			assert_bool(rect.intersects(hand)).override_failure_message(where + " hand").is_false()


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = code
		key.keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	await await_idle_frame()
	await await_idle_frame()

extends GdUnitTestSuite
## Three things seen in the menu pages' frames (P5.2a): the Collection's text is ink on
## its paper, with no halo; the two Settings sheets stand as tall as each other; and run
## setup's papers stand into the page's spare room, with nothing moving when a stake is
## picked.

const SAVE_PATH: String = "user://test_menu_pages/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
## The most of run setup's sheet that may stand empty under the rules at 1080.
const EMPTY_AT_MOST: float = 0.12

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	_app.demo = false
	add_child(_app)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


## A profile with three finished runs and the third stake unlocked.
func _veteran() -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 3
	data.generation = 3
	data.stake = 2
	Profile.write(Saves.profile_service(), data)


func _open(screen_id: String) -> Control:
	var screen: Control = _app.show_screen(screen_id, true)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func test_the_collections_text_is_ink_with_no_halo() -> void:
	var screen: CollectionScreen = await _open("collection")
	var labels: Array[Node] = screen.find_children("*", "Label", true, false)
	assert_int(labels.size()).is_greater(10)
	for node: Node in labels:
		var label: Label = node as Label
		var where: String = "%s '%s'" % [label.get_path(), label.text.left(30)]
		var halo: int = label.get_theme_constant("outline_size")
		assert_int(halo).override_failure_message(where).is_equal(0)


func test_the_settings_sheets_stand_as_tall_as_each_other() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			var screen: SettingsScreen = await _open("settings")
			# A new text size builds the page again a frame later.
			await await_idle_frame()
			screen = _app.switcher.current()
			var sheets: Array[Control] = screen.sheets()
			assert_int(sheets.size()).is_equal(2)
			var left: Rect2 = sheets[0].get_global_rect()
			var right: Rect2 = sheets[1].get_global_rect()
			var where: String = "size %d %s: %s and %s" % [level, screen_size, left, right]
			var level_tops: bool = absf(left.position.y - right.position.y) <= SLACK
			var level_feet: bool = absf(left.end.y - right.end.y) <= SLACK
			assert_bool(level_tops and level_feet).override_failure_message(where).is_true()


func test_run_setups_papers_stand_into_the_spare_room() -> void:
	get_tree().root.size = SIZES[0]
	var screen: RunSetupScreen = await _open("run_setup")
	var content: Control = screen.scroll().get_child(0)
	var foot: Control = content.get_child(content.get_child_count() - 1)
	var tall: float = screen.scroll().size.y
	var where: String = "foot %.0f of %.0f" % [foot.size.y, tall]
	assert_float(foot.size.y).override_failure_message(where).is_less(tall * EMPTY_AT_MOST)
	for paper: AgedSheet in screen.papers():
		assert_float(paper.size.y).is_greater(RunSetupScreen.PAPER_MIN.y + 40.0)
	# Nothing has to scroll for it.
	assert_float(content.size.y).is_less_equal(tall + SLACK)


func test_picking_a_stake_moves_nothing_on_run_setup() -> void:
	_veteran()
	get_tree().root.size = SIZES[0]
	var screen: RunSetupScreen = await _open("run_setup")
	var tickets: Array[StakeTicket] = screen.tickets()
	var before: Array[Rect2] = []
	for piece: Control in screen.papers() + tickets:
		before.append(piece.get_global_rect())
	var lines: Dictionary[int, bool] = {}
	for stake: int in 3:
		tickets[stake].pressed.emit()
		await await_idle_frame()
		await await_idle_frame()
		lines[screen.rules_text().count("\n")] = true
		var at: int = 0
		for piece: Control in screen.papers() + tickets:
			var where: String = "stake %d moved %s" % [stake, piece.get_path()]
			var still: bool = piece.get_global_rect().is_equal_approx(before[at])
			assert_bool(still).override_failure_message(where).is_true()
			at += 1
	# The rules did change length, so room was kept for the longest.
	assert_int(lines.size()).is_greater(1)

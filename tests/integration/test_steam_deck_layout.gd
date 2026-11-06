extends GdUnitTestSuite
## Nothing clips at 1280x800, the Steam Deck's screen (P3B.11). With the canvas_items
## stretch and expand aspect, a 16:10 window shows a 1920x1200 canvas. Every screen is
## opened at that size, and every visible control must sit inside the visible area, with
## no single-line label or button text wider than its own box.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_steam_deck_layout/run.json"
const DECK: Vector2i = Vector2i(1280, 800)
## Sub-pixel rounding allowance, in canvas pixels.
const SLACK: float = 1.5

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = DECK
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_the_canvas_is_16_by_10() -> void:
	var visible: Rect2 = get_tree().root.get_visible_rect()
	assert_float(visible.size.x / visible.size.y).is_equal_approx(1.6, 0.01)


func test_no_screen_clips_at_1280_by_800() -> void:
	var problems: PackedStringArray = []
	for screen_id: String in DemoApp.SCREENS:
		if not ResourceLoader.exists(DemoApp.SCREENS[screen_id]):
			continue
		var screen: Node = _app.show_screen(screen_id, true)
		await await_idle_frame()
		await await_idle_frame()
		_check(screen, screen_id, problems)
	assert_array(problems).is_empty()


func test_the_table_menus_do_not_clip() -> void:
	var problems: PackedStringArray = []
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	table.call("_open_pause")
	await await_idle_frame()
	_check(table, "pause", problems)
	var pause: PauseMenu = table.get("_pause")
	pause.close()
	var sheet: CheatSheet = table.get("_cheat_sheet")
	sheet.toggle(_app.controller)
	await await_idle_frame()
	_check(table, "cheat sheet", problems)
	assert_array(problems).is_empty()


## The check itself catches text that grows past the screen's edge and a control off
## screen. Labels grow to fit their text, so overflow shows up as leaving the screen.
func test_the_check_catches_overflow_and_offscreen() -> void:
	var holder: Control = auto_free(Control.new())
	add_child(holder)
	var narrow: Label = Label.new()
	narrow.text = "A label far too long for the space left on the right"
	holder.add_child(narrow)
	narrow.position = Vector2(1700, 40)
	var lost: Panel = Panel.new()
	holder.add_child(lost)
	lost.position = Vector2(1900, 1190)
	lost.size = Vector2(200, 200)
	await await_idle_frame()
	var problems: PackedStringArray = []
	_check(holder, "sample", problems)
	assert_int(problems.size()).is_equal(2)


func _check(node: Node, where: String, problems: PackedStringArray) -> void:
	var visible: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return
		var rect: Rect2 = control.get_global_rect()
		var drawn: bool = rect.size.x > 0.0 and rect.size.y > 0.0 and control.modulate.a > 0.0
		if drawn and not visible.encloses(rect) and not _is_backdrop(control):
			problems.append("%s: %s at %s" % [where, control.get_path(), rect])
		var overflow: float = _text_overflow(control)
		if overflow > SLACK:
			problems.append("%s: %s text %.0f px too wide" % [where, control.get_path(), overflow])
	for child: Node in node.get_children():
		_check(child, where, problems)


## How far single-line text runs past its control's width, or 0.
func _text_overflow(control: Control) -> float:
	var label: Label = control as Label
	if (
		label != null
		and label.autowrap_mode == TextServer.AUTOWRAP_OFF
		and not label.text.is_empty()
	):
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var width: float = 0.0
		for line: String in label.text.split("\n"):
			width = maxf(
				width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
		return width - label.size.x
	var button: Button = control as Button
	if button != null and not button.text.is_empty() and not button.clip_text:
		return button.get_combined_minimum_size().x - button.size.x
	return 0.0


## Full-screen art and the offscreen card-pool parent are allowed past the edges.
func _is_backdrop(control: Control) -> bool:
	if control is TextureRect or control is ColorRect:
		return true
	return control.get_global_rect().position.x < -1000.0

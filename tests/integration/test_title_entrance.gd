extends GdUnitTestSuite
## The title's arrival (P5.2a): the poster is laid down, the eyebrow fades in, the name
## is pressed letter by letter, and the minor row comes last, the whole page in about a
## second and a half and every button live from the first frame. Under reduced motion it
## stands printed at once. The name is never clean and sits worse at each stage.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
## The page is whole by this, the motion rule's "about a second and a half".
const WHOLE_BY: float = 1.6
const SLACK_MSEC: int = 300

var _app: DemoApp
var _was_motion: bool
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	_was_motion = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", _was_motion)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _button(title: TitleScreen, key: String) -> Button:
	for node: Node in title.find_children("*", "Button", true, false):
		if (node as Button).text == tr(key):
			return node as Button
	return null


## The row of minor buttons, which Quit stands in.
func _minor(title: TitleScreen) -> Control:
	return _button(title, "title.quit").get_parent() as Control


func _eyebrow(title: TitleScreen) -> Label:
	for node: Node in title.find_children("*", "Label", true, false):
		if (node as Label).text == tr("title.eyebrow").to_upper():
			return node as Label
	return null


func test_the_title_arrives_in_order_and_is_whole_in_time() -> void:
	var presets: MotionPresets = UiMotion.PRESETS
	var title: TitleScreen = _app.show_screen("title", true)
	var word: TitleWord = title.word()
	var eyebrow: Label = _eyebrow(title)
	var start: Button = _button(title, "title.new_run")
	var minor: Control = _minor(title)
	var last: int = word.text.length() - 1
	# Nothing is in yet, and the button that starts a run already holds the focus.
	assert_float(eyebrow.modulate.a).is_equal(0.0)
	assert_float(minor.modulate.a).is_equal(0.0)
	assert_float(word.landed(0)).is_equal(0.0)
	assert_float(title.poster().scale.x).is_greater(1.0)
	assert_bool(start.has_focus()).is_true()
	assert_float(title.arrives_in()).is_greater(1.0)
	assert_float(title.arrives_in()).is_less_equal(WHOLE_BY)
	# Part way: the eyebrow and the first letter are coming, the last letter is not down
	# and the minor row has not started.
	await await_millis(int((presets.title_start + presets.title_stagger + 0.25) * 1000.0))
	assert_float(eyebrow.modulate.a).is_greater(0.0)
	assert_float(word.landed(0)).is_greater(0.0)
	assert_float(word.landed(last)).is_less(1.0)
	assert_float(minor.modulate.a).is_equal(0.0)
	await await_millis(int(maxf(title.arrives_in(), presets.settle_time) * 1000.0) + SLACK_MSEC)
	assert_bool(word.is_printed()).is_true()
	for piece: Control in [eyebrow, start, minor]:
		assert_float(piece.modulate.a).is_equal_approx(1.0, 0.01)
	assert_vector(title.poster().scale).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
	# The entrance left the focused button its lift.
	var lifted: Vector2 = Vector2.ONE * presets.hover_scale
	assert_vector(start.scale).is_equal_approx(lifted, Vector2(0.01, 0.01))


func test_reduced_motion_prints_the_title_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var title: TitleScreen = _app.show_screen("title", true)
	assert_bool(title.word().is_printed()).is_true()
	assert_float(title.arrives_in()).is_equal(0.0)
	assert_float(_eyebrow(title).modulate.a).is_equal(1.0)
	assert_float(_minor(title).modulate.a).is_equal(1.0)
	assert_vector(title.poster().scale).is_equal(Vector2.ONE)


func test_the_name_stands_inside_the_screen_as_wide_as_its_type() -> void:
	Settings.set_value("reduced_motion", true)
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		var title: TitleScreen = _app.show_screen("title", true)
		await await_idle_frame()
		await await_idle_frame()
		var word: TitleWord = title.word()
		var px: int = TextSize.px(TitleWord.SIZE)
		var font: Font = ScreenKit.DISPLAY_BOLD
		var type: Vector2 = font.get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px)
		assert_str(word.text).is_equal(tr("game.title"))
		assert_float(word.size.x).is_greater_equal(type.x)
		assert_float(word.size.y).is_greater_equal(float(px))
		assert_float(word.size.y).is_less(font.get_height(px))
		var screen: Rect2 = title.get_global_rect()
		var where: String = "%s %s" % [screen_size, word.get_global_rect()]
		var inside: bool = screen.encloses(word.get_global_rect())
		assert_bool(inside).override_failure_message(where).is_true()


## At Standard the column keeps to the poster's sky, so no button lies on a face in the
## crowd, and the name's box is close under the eyebrow.
func test_the_column_stands_in_the_sky_above_the_crowd() -> void:
	Settings.set_value("reduced_motion", true)
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		var title: TitleScreen = _app.show_screen("title", true)
		await await_idle_frame()
		await await_idle_frame()
		var page: Rect2 = title.get_global_rect()
		var foot: float = _minor(title).get_global_rect().end.y
		var where: String = "%s foot at %.0f of %.0f" % [screen_size, foot, page.size.y]
		var in_sky: bool = foot <= page.position.y + page.size.y * TitleScreen.SKY
		assert_bool(in_sky).override_failure_message(where).is_true()
		var gap: float = title.word().get_global_rect().position.y
		gap -= _eyebrow(title).get_global_rect().end.y
		assert_float(gap).is_less(60.0)


func test_the_type_is_never_clean_and_sits_worse_at_each_stage() -> void:
	assert_float(TitleWord.slip(0)).is_greater(0.0)
	assert_float(TitleWord.unevenness(0)).is_equal(1.0)
	for stage: int in range(1, 10):
		assert_float(TitleWord.slip(stage)).is_greater(TitleWord.slip(stage - 1))
		assert_float(TitleWord.unevenness(stage)).is_greater(TitleWord.unevenness(stage - 1))
	# The vermilion pass never leaves the ink line it is printed inside.
	assert_float(TitleWord.slip(9)).is_less(TitleWord.OUTLINE / 2.0)

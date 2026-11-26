extends GdUnitTestSuite
## ADR 0037's two notices: "already open" and, on the title after a session that did not
## close, where its files were copied; and the question after a new window mode. Each
## stands whole inside the window at both sizes
## and every text size, with its buttons on the sheet; the title's is said once, with OK
## focused, taken by keyboard, and a button that opens the folder.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
## A folder named as the game names one, under the deepest user folder a player may have.
const KEPT: String = "user://crashes/2000-01-01T00.00.00"
const SLACK: float = 1.5

static var _save_path: String = TestFolder.of("test_session_notice") + "run.json"

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	_app = AppKit.make(self)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _assert_whole(notice: SessionNotice, where: String) -> void:
	var window: Rect2 = notice.get_viewport_rect().grow(SLACK)
	var sheet: Rect2 = notice.sheet().get_global_rect()
	assert_bool(window.encloses(sheet)).override_failure_message(where + " sheet").is_true()
	for button: Button in notice.buttons():
		var rect: Rect2 = button.get_global_rect()
		assert_bool(sheet.grow(SLACK).encloses(rect)).override_failure_message(where).is_true()


func test_every_notice_stands_whole_at_every_size() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			var notices: Array[SessionNotice] = [
				SessionNotice.already_open(20, func() -> void: pass, func() -> void: pass),
				SessionNotice.kept(KEPT),
				SessionNotice.display_check(10, func() -> void: pass, func() -> void: pass),
			]
			for notice: SessionNotice in notices:
				_app.add_child(notice)
				await await_idle_frame()
				await await_idle_frame()
				_assert_whole(notice, "text size %d at %s" % [level, screen_size])
				notice.free()


func test_the_title_says_once_where_the_last_session_was_kept() -> void:
	_app.kept_crash = KEPT
	var title: TitleScreen = _app.show_screen("title", true)
	await await_idle_frame()
	await await_idle_frame()
	var notice: SessionNotice = null
	for child: Node in title.get_children():
		if child is SessionNotice:
			notice = child
	assert_object(notice).is_not_null()
	assert_str(_app.kept_crash).is_empty()
	var buttons: Array[Button] = notice.buttons()
	assert_str(buttons[0].text).is_equal(tr("session.kept.ok"))
	assert_str(buttons[1].text).is_equal(tr("session.kept.open"))
	assert_object(get_viewport().gui_get_focus_owner()).is_same(buttons[0])
	var shown: String = ProjectSettings.globalize_path(KEPT)
	var texts: Array[String] = []
	for label: Node in notice.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_array(texts).contains([shown])
	await TestInput.tap_key(self, KEY_ENTER)
	await await_idle_frame()
	assert_bool(is_instance_valid(notice)).is_false()
	var new_run: Button = null
	for node: Node in title.find_children("*", "Button", true, false):
		if (node as Button).text == tr("title.new_run"):
			new_run = node
	assert_object(get_viewport().gui_get_focus_owner()).is_same(new_run)
	# Said once: the title again shows none.
	title = _app.show_screen("title", true)
	await await_idle_frame()
	for child: Node in title.get_children():
		assert_bool(child is SessionNotice).is_false()

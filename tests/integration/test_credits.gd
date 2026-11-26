extends GdUnitTestSuite
## The credits, from the title: they say what LICENSE, the fonts' licences, the art and
## sound records and the engine say, stand whole at both screens and every text size with
## the cut faded, scroll by keys, and go back by Back or Escape.

static var _save_path: String = TestFolder.of("test_credits") + "run.json"

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	_app = AppKit.make(self)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _credits() -> CreditsScreen:
	var title: Control = _app.show_screen("title", true)
	await await_idle_frame()
	for node: Node in title.find_children("*", "Button", true, false):
		if (node as Button).text == tr("title.credits"):
			(node as Button).pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	var shown: CreditsScreen = _app.switcher.current() as CreditsScreen
	assert_object(shown).is_not_null()
	return shown


func _words(screen: CreditsScreen) -> String:
	var all: PackedStringArray = []
	for node: Node in screen.find_children("*", "Label", true, false):
		all.append((node as Label).text)
	return "\n".join(all)


func test_the_credits_say_what_their_sources_say() -> void:
	var words: String = _words(await _credits())
	var data: Dictionary = CreditsScreen.CREDITS.data
	var needed: PackedStringArray = [
		tr("credits.game"),
		str(data["licence"]).get_slice("\n", 0),
		"Kenney Vleugels",
		"radwoc",
		"GPT Image",
		Engine.get_license_text().strip_edges().get_slice("\n", 0),
		str(Engine.get_copyright_info()[0]["name"]),
		str(Engine.get_license_info().keys()[0]),
	]
	for font: Dictionary in data["fonts"]:
		needed.append(str(font["name"]))
		var path: String = "res://" + str(font["file"])
		assert_bool(FileAccess.file_exists(path)).override_failure_message(path).is_true()
		needed.append(FileAccess.get_file_as_string(path).strip_edges().get_slice("\n", 0))
	for piece: String in needed:
		assert_bool(words.contains(piece)).override_failure_message(piece).is_true()


func test_the_credits_stand_whole_at_every_size() -> void:
	for level: int in TextSize.count():
		for screen_size: Vector2i in ClipCheck.SIZES:
			Settings.set_value(TextSize.SETTING, level)
			get_tree().root.size = screen_size
			var where: String = "text size %d at %s" % [level, screen_size]
			var screen: CreditsScreen = await _credits()
			var view: Rect2 = screen.get_viewport_rect().grow(ClipCheck.SLACK)
			for piece: Control in [screen.scroll(), screen.back_button()]:
				var rect: Rect2 = piece.get_global_rect()
				assert_bool(view.encloses(rect)).override_failure_message(where).is_true()
			var fade: ScrollFade = screen.scroll().find_child("ScrollFade", false, false)
			assert_bool(fade.more_below()).override_failure_message(where).is_true()
			var problems: PackedStringArray = []
			ClipCheck.check(screen, where, problems, true)
			assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


func test_keys_scroll_the_credits_and_escape_goes_back() -> void:
	var screen: CreditsScreen = await _credits()
	assert_bool(screen.scroll().has_focus()).is_true()
	var before: int = screen.scroll().scroll_vertical
	await _action("ui_down")
	assert_int(screen.scroll().scroll_vertical).is_greater(before)
	await _action("ui_cancel")
	assert_str(_app.switcher.current_id()).is_equal("title")


func _action(action: String) -> void:
	for down: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await await_idle_frame()

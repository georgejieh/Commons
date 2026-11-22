extends GdUnitTestSuite
## The ending screen (ADR 0024) for every ending and both deaths, at 1920x1080 and at the
## Steam Deck's 1280x800, with all 14 families: everything is on the screen, or in the
## epilogue's list, which scrolls and takes focus when it overflows; the type is large
## dark ink; the lines arrive one after another and an accept press shows the rest; reduced
## motion shows them at once; the note is only where it belongs; a death has no
## epilogue; and a run's real end reaches it, while the demo keeps its own closing.

const SAVE_PATH: String = "user://test_ending_screen/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
const READABLE: int = 16
## Each outcome's Famine, Denunciation and rounds as landlord of four.
const CASES: Dictionary[String, Array] = {
	"secret_contract": [30, 20, 0],
	"the_commons": [10, 10, 0],
	"lean_years": [80, 20, 1],
	"labeled": [20, 80, 1],
	"benevolent_landlord": [30, 30, 3],
	"full_granary": [85, 40, 4],
	"struggled": [40, 90, 2],
	"death_famine": [100, 40, 1],
	"death_denunciation": [40, 100, 1],
}

var _app: DemoApp
var _was_size: Vector2i
var _was_reduced: bool


func before_test() -> void:
	_was_size = get_tree().root.size
	_was_reduced = bool(Settings.value("reduced_motion"))
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Settings.set_value("reduced_motion", _was_reduced)
	Saves.run_service().delete()


## A run finished with the given outcome's numbers and a full village: warm, wary and
## bitter families, one in reeducation, one deposed and two dead. Saved, then picked up
## the way Continue does.
func _finish(outcome: String) -> EndingScreen:
	var values: Array = CASES[outcome]
	var state: RunState = RunState.new(77)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.famine = values[0]
	state.denunciation = values[1]
	state.resentment = 0 if outcome == "the_commons" else 40
	state.year_rounds = 4
	state.year_landlord_rounds = values[2]
	for family: FamilyDef in RunLoop.DEFAULT_VILLAGE.families:
		state.roster.append(RosterEntry.new(family.id))
	state.roster[1].status = RosterEntry.Status.REEDUCATION
	state.roster[4].status = RosterEntry.Status.DEPOSED
	state.roster[6].status = RosterEntry.Status.DEAD
	state.roster[11].status = RosterEntry.Status.DEAD
	var summary: SetSummary = SetSummary.new(0)
	summary.add(state.roster[0].family_id, SetSummary.Kind.FED, 4)
	summary.add(state.roster[2].family_id, SetSummary.Kind.DENOUNCED, 3)
	summary.add(state.roster[3].family_id, SetSummary.Kind.BOMBED, 1)
	state.memory.record(summary)
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	Saves.run_service().save(record.to_dict())
	_app.resume_to_screen()
	assert_str(_app.switcher.current_id()).is_equal("ending")
	return _app.switcher.current()


func _labels(root: Node) -> Array[Label]:
	var found: Array[Label] = []
	for node: Node in root.find_children("*", "Label", true, false):
		found.append(node as Label)
	return found


func _check_inside(screen: EndingScreen, where: String) -> void:
	var visible_rect: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var list: EpilogueList = screen.epilogue()
	for node: Node in screen.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control is TextureRect or control is ColorRect:
			continue
		if list != null and list.is_ancestor_of(control):
			continue
		var rect: Rect2 = control.get_global_rect()
		(
			assert_bool(visible_rect.encloses(rect))
			. override_failure_message("%s: %s at %s" % [where, control.get_path(), rect])
			. is_true()
		)


## The meters and class are figures, not prose: they stand outside the story's scroll,
## whole on the screen beside the way home, so no fold can cut a tile (ADR 0034).
func _check_figures(screen: EndingScreen, where: String) -> void:
	var figures: HBoxContainer = screen.figures()
	var scrolled: bool = screen.story_scroll().is_ancestor_of(figures)
	assert_bool(scrolled).override_failure_message(where).is_false()
	assert_int(figures.get_child_count()).is_equal(3)
	var visible_rect: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var home: Rect2 = screen.home_button().get_global_rect()
	for tile: Node in figures.get_children():
		var rect: Rect2 = (tile as Control).get_global_rect()
		var at: String = "%s: %s" % [where, rect]
		assert_bool(visible_rect.encloses(rect)).override_failure_message(at).is_true()
		assert_bool(rect.intersects(home)).override_failure_message(at).is_false()
		assert_bool(rect.intersects(screen.story_scroll().get_global_rect())).is_false()


func _check_type(screen: EndingScreen, view: EndingView, where: String) -> void:
	var title_size: int = 0
	var largest: int = 0
	for label: Label in _labels(screen):
		var font_size: int = label.get_theme_font_size("font_size")
		largest = maxi(largest, font_size)
		if label.text == view.title:
			title_size = font_size
		elif label.text == view.text or view.lines.has(label.text):
			assert_int(font_size).override_failure_message(where).is_greater_equal(20)
			assert_object(label.get_theme_color("font_color")).is_equal(ScreenKit.INK)
		elif label.text == view.note:
			assert_int(font_size).is_equal(TextSize.px(EndingScreen.NOTE_SIZE))
			assert_object(label.get_theme_color("font_color")).is_equal(ScreenKit.INK)
		elif label.is_visible_in_tree() and not label.text.is_empty():
			assert_int(font_size).override_failure_message(label.text).is_greater_equal(READABLE)
	assert_int(title_size).override_failure_message(where).is_equal(largest)
	assert_int(title_size).is_greater_equal(EndingScreen.TITLE_MIN)


func test_every_ending_and_death_fits_both_screens_with_a_full_village() -> void:
	Settings.set_value("reduced_motion", true)
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			for outcome: String in CASES:
				var screen: EndingScreen = _finish(outcome)
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "%s %s" % [outcome, screen_size]
				var view: EndingView = _app.controller.ending()
				assert_str(view.id).override_failure_message(where).is_equal(outcome)
				_check_inside(screen, where)
				_check_figures(screen, where)
				# The title card gives up height first, so the story stands whole (P5.2a).
				var story: VScrollBar = screen.story_scroll().get_v_scroll_bar()
				var at: String = "%s at text size %d" % [where, level]
				assert_float(story.max_value).override_failure_message(at).is_less_equal(
					story.page + SLACK
				)
				_check_type(screen, view, where)
				_clips(screen, where)
				var list: EpilogueList = screen.epilogue()
				if view.death:
					assert_object(list).override_failure_message(where).is_null()
					continue
				# Twelve living families on five shared lines (warm, wary, bitter and the two
				# states), and the dead named on the two roll-call endings.
				var roll_call: bool = outcome == "lean_years" or outcome == "full_granary"
				assert_int(list.line_labels().size()).is_equal(5 + (1 if roll_call else 0))
				var bar: VScrollBar = list.get_v_scroll_bar()
				if bar.max_value > bar.page + 1.0:
					assert_bool(list.can_scroll()).override_failure_message(where).is_true()
				else:
					for label: Label in list.line_labels():
						var rect: Rect2 = label.get_global_rect()
						assert_bool(list.get_global_rect().grow(SLACK).encloses(rect)).is_true()


func test_the_note_shows_only_under_the_secret_contract_and_the_commons() -> void:
	Settings.set_value("reduced_motion", true)
	var note: String = tr("ending.note.xiaogang")
	for outcome: String in CASES:
		var screen: EndingScreen = _finish(outcome)
		await await_idle_frame()
		var shown: bool = _labels(screen).any(func(label: Label) -> bool: return label.text == note)
		var belongs: bool = outcome == "secret_contract" or outcome == "the_commons"
		assert_bool(shown).override_failure_message(outcome).is_equal(belongs)


func test_the_lines_arrive_one_by_one_and_an_accept_press_shows_the_rest() -> void:
	Settings.set_value("reduced_motion", false)
	var screen: EndingScreen = _finish("secret_contract")
	await await_idle_frame()
	await await_idle_frame()
	var list: EpilogueList = screen.epilogue()
	assert_bool(screen.is_revealing()).is_true()
	assert_int(list.shown_count()).is_less(list.line_labels().size())
	assert_object(get_viewport().gui_get_focus_owner()).is_same(screen.show_all_button())
	await get_tree().create_timer(UiMotion.PRESETS.epilogue_beat * 2.5).timeout
	assert_int(list.shown_count()).is_between(1, list.line_labels().size() - 1)
	var accept: InputEventAction = InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	get_tree().root.push_input(accept)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(screen.is_revealing()).is_false()
	assert_int(list.shown_count()).is_equal(list.line_labels().size())
	for label: Label in list.line_labels():
		assert_float(label.modulate.a).is_greater(0.0)
	assert_bool(screen.show_all_button().visible).is_false()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(screen.home_button())


func test_reduced_motion_shows_every_line_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var screen: EndingScreen = _finish("struggled")
	await await_idle_frame()
	await await_idle_frame()
	var list: EpilogueList = screen.epilogue()
	assert_bool(screen.is_revealing()).is_false()
	for label: Label in list.line_labels():
		assert_float(label.modulate.a).is_equal(1.0)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(screen.home_button())


func test_a_death_has_its_record_and_the_way_home_only() -> void:
	Settings.set_value("reduced_motion", true)
	var screen: EndingScreen = _finish("death_denunciation")
	await await_idle_frame()
	await await_idle_frame()
	var texts: Array[String] = []
	for label: Label in _labels(screen):
		texts.append(label.text)
	assert_array(texts).contains([tr("death.denunciation.title")])
	var buttons: Array[Node] = screen.find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_equal(1)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(screen.home_button())


## A death's page has no epilogue beside it, so its column sits in the middle of the
## sheet both ways: as much room above its title card as below its last line.
func test_a_deaths_column_is_centred_on_the_sheet() -> void:
	Settings.set_value("reduced_motion", true)
	get_tree().root.size = SIZES[0]
	var screen: EndingScreen = _finish("death_famine")
	for frame: int in 4:
		await await_idle_frame()
	var heading: Control = screen.get("_heading")
	# The story is centred in its scroll, which fills the columns (ADR 0034).
	var story: Control = heading
	while story != null and not (story.get_parent() is CenterContainer):
		story = story.get_parent() as Control
	var columns: Control = screen.story_scroll()
	var above: float = story.global_position.y - columns.global_position.y
	var below: float = columns.get_global_rect().end.y - story.get_global_rect().end.y
	assert_float(above).is_greater(0.0)
	assert_float(absf(above - below)).is_less_equal(2.0)


func test_a_long_epilogue_scrolls_by_keyboard_from_its_focus() -> void:
	Settings.set_value("reduced_motion", true)
	get_tree().root.size = SIZES[0]
	var screen: EndingScreen = _finish("lean_years")
	var list: EpilogueList = screen.epilogue()
	var many: Array[String] = []
	for index: int in 40:
		many.append("Line %d of a long epilogue that runs on past the page." % index)
	list.set_lines(many)
	list.show_all()
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(list.can_scroll()).is_true()
	list.grab_focus()
	var down: InputEventAction = InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	get_tree().root.push_input(down)
	await await_idle_frame()
	assert_int(list.scroll_vertical).is_greater(0)


func test_the_page_leaves_nothing_behind_when_it_goes_home() -> void:
	Settings.set_value("reduced_motion", false)
	var screen: EndingScreen = _finish("labeled")
	await await_idle_frame()
	screen.home_button().pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("title")
	assert_bool(is_instance_valid(screen)).is_false()


func test_the_runs_end_reaches_the_ending_and_the_demo_keeps_its_closing() -> void:
	_app.new_run(4242)
	assert_str(_app.screen_for(RunController.AWAIT_RUN_OVER)).is_equal("year_summary")
	_finish("benevolent_landlord")
	assert_str(_app.screen_for(RunController.AWAIT_RUN_OVER)).is_equal("ending")


## Every ending and death shows its picture whole, at its own shape, inside the printed
## frame, with the title under the frame, at both screen sizes.
func test_every_ending_hangs_its_picture_in_the_frame_with_the_title_below() -> void:
	Settings.set_value("reduced_motion", true)
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		for outcome: String in CASES:
			var screen: EndingScreen = _finish(outcome)
			await await_idle_frame()
			await await_idle_frame()
			var where: String = "%s %s" % [outcome, screen_size]
			assert_bool(ScreenKit.ART.has_ending(outcome)).override_failure_message(where).is_true()
			var pictures: Array[Node] = screen.find_children(
				"EndingPicture", "TextureRect", true, false
			)
			assert_int(pictures.size()).override_failure_message(where).is_equal(1)
			var art: TextureRect = pictures[0]
			assert_object(art.texture).override_failure_message(where).is_not_null()
			var frames: Array[Node] = screen.find_children("*", "ArtFrame", true, false)
			assert_int(frames.size()).override_failure_message(where).is_equal(1)
			var frame: Rect2 = (frames[0] as Control).get_global_rect()
			var shown: Rect2 = art.get_global_rect()
			assert_bool(frame.grow(SLACK).encloses(shown)).override_failure_message(where).is_true()
			var picture: Vector2 = Vector2(art.texture.get_size())
			var box: float = shown.size.x / shown.size.y
			# The frame fits the picture, so the picture fills it at its own shape.
			assert_float(box).override_failure_message(where).is_equal_approx(
				picture.x / picture.y, 0.06
			)
			var title: Label = _title_label(screen, _app.controller.ending().title)
			(
				assert_float(title.get_global_rect().position.y)
				. override_failure_message(where)
				. is_greater_equal(frame.end.y - SLACK)
			)


func _title_label(screen: EndingScreen, text: String) -> Label:
	for label: Label in _labels(screen):
		if label.text == text:
			return label
	return null


## Until an ending has its picture, its title sits in the printed frame at the top.
func test_an_ending_without_art_sets_its_title_in_the_frame() -> void:
	Settings.set_value("reduced_motion", true)
	var art: ArtLibrary = ScreenKit.ART
	var endings: Dictionary[String, String] = art.endings
	var kept: String = endings["full_granary"]
	endings.erase("full_granary")
	var screen: EndingScreen = _finish("full_granary")
	await await_idle_frame()
	endings["full_granary"] = kept
	assert_int(screen.find_children("EndingPicture", "TextureRect", true, false).size()).is_equal(0)
	assert_int(screen.find_children("*", "ArtFrame", true, false).size()).is_equal(1)
	# No face here holds the seal's characters, so Struggled's seal is left out, not boxed.
	assert_bool(HanziSeal.can_draw("斗地主")).is_equal(ScreenKit.ART.hanzi_font != null)


## Nothing under root clips, as ClipCheck says (ADR 0034).
func _clips(root: Node, where: String) -> void:
	var problems: PackedStringArray = []
	ClipCheck.check(root, "%s at text size %d" % [where, TextSize.level()], problems)
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()

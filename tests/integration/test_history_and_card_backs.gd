extends GdUnitTestSuite
## The village history's past generations and Settings' card backs (ADR 0025), at
## 1920x1080 and at 1280x800: every line on screen or in the scroll, which follows focus;
## type 18 px or more; the exact record line; locked designs as blank sheets saying when
## they open; a chosen design no longer open falling back to the first; and play the same
## whichever back is chosen. The history page is one ink sheet across the page, and the
## run in progress reads as a record, one line per family a Quota touched.

const SAVE_PATH: String = "user://test_history_and_card_backs/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
const READABLE: int = 18
const SEED: int = 9321
## The darkest a page's ink may be read as light: its luminance stays under this.
const DARK_INK: float = 0.35

var _app: DemoApp
var _was_size: Vector2i
var _was_back: String


func before_test() -> void:
	_was_size = get_tree().root.size
	_was_back = str(Settings.value(CardBacks.SETTING))
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	Saves.profile_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)


func after_test() -> void:
	get_tree().root.size = _was_size
	Settings.set_value(CardBacks.SETTING, _was_back)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _entry(generation: int, outcome: String, landlord: bool, dead: Array[String]) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new()
	entry.run_id = "run-%d" % generation
	entry.generation = generation
	entry.outcome = outcome
	entry.class_id = HistoryEntry.LANDLORD if landlord else HistoryEntry.PEASANT
	entry.year = 8 if not Endings.is_death(outcome) else 3
	entry.dead = dead
	return entry


func _keys(count: int) -> Array[String]:
	var keys: Array[String] = []
	for index: int in count:
		keys.append(RunLoop.DEFAULT_VILLAGE.families[index].name_key)
	return keys


func _write_history(entries: Array[HistoryEntry]) -> void:
	var data: ProfileData = ProfileData.new()
	for entry: HistoryEntry in entries:
		data.add_history(entry)
	data.finished_runs = entries.size()
	Profile.write(Saves.profile_service(), data)


func _history() -> VillageHistoryScreen:
	var screen: VillageHistoryScreen = _app.show_screen("village_history", true)
	await await_idle_frame()
	await await_idle_frame()
	return screen


func test_a_generations_line_reads_exactly() -> void:
	var names: Array[String] = _keys(3)
	var entry: HistoryEntry = _entry(3, Endings.LEAN_YEARS, false, names.slice(0, 2))
	var expected: String = (
		"Generation 3. Lean Years. Class: Peasant. Ended in Year 8. Not at roll call: %s and %s."
		% [tr(names[0]), tr(names[1])]
	)
	assert_str(HistoryView.line(entry)).is_equal(expected)
	var three: HistoryEntry = _entry(4, Endings.FULL_GRANARY, true, names)
	assert_str(HistoryView.line(three)).ends_with(
		"Not at roll call: %s, %s and %s." % [tr(names[0]), tr(names[1]), tr(names[2])]
	)
	var death: HistoryEntry = _entry(5, Endings.DEATH_FAMINE, true, [])
	assert_str(HistoryView.line(death)).is_equal(
		"Generation 5. The Granary Is Empty. Class: Landlord. Ended in Year 3."
	)


func test_no_generation_yet() -> void:
	var screen: VillageHistoryScreen = await _history()
	assert_int(screen.records().size()).is_equal(1)
	assert_str(screen.records()[0].accessibility_name).is_equal(
		"No generation has finished a run yet."
	)


## Fifty generations, newest first, all reached by scrolling with focus at both sizes,
## in type 18 px or more.
func test_fifty_generations_scroll_by_focus_at_both_sizes() -> void:
	var entries: Array[HistoryEntry] = []
	for index: int in ProfileData.HISTORY_CAP:
		var dead: Array[String] = []
		if index % 7 == 0:
			dead = _keys(2)
		entries.append(_entry(index + 1, Endings.ENDINGS[index % 7], index % 2 == 0, dead))
	_write_history(entries)
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		var screen: VillageHistoryScreen = await _history()
		var where: String = str(screen_size)
		var records: Array[AgedSheet] = screen.records()
		assert_int(records.size()).override_failure_message(where).is_equal(50)
		assert_str(records[0].accessibility_name).is_equal(HistoryView.line(entries[-1]))
		assert_str(records[-1].accessibility_name).is_equal(HistoryView.line(entries[0]))
		_check_type(screen, where)
		var visible: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
		assert_bool(visible.encloses(screen.back_button().get_global_rect())).is_true()
		assert_bool(visible.encloses(screen.scroll().get_global_rect())).is_true()
		# The arrows and the d-pad walk the sheets, and the scroll follows to the last.
		assert_object(records[0].find_valid_focus_neighbor(SIDE_BOTTOM)).is_same(records[1])
		records[-1].grab_focus()
		await await_idle_frame()
		await await_idle_frame()
		var view: Rect2 = screen.scroll().get_global_rect().grow(SLACK)
		(
			assert_bool(view.encloses(records[-1].get_global_rect()))
			. override_failure_message(where)
			. is_true()
		)


func _check_type(root: Node, where: String) -> void:
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text.is_empty() or not label.is_visible_in_tree():
			continue
		var used: int = label.get_theme_font_size("font_size")
		(
			assert_int(used)
			. override_failure_message("%s: %s %d" % [where, label.text, used])
			. is_greater_equal(READABLE)
		)


func _summary(number: int, rows: Dictionary) -> SetSummary:
	var summary: SetSummary = SetSummary.new(number)
	for family: String in rows:
		var deeds: Array = rows[family]
		for kind: int in deeds.size():
			summary.add(family, kind as SetSummary.Kind, deeds[kind])
	return summary


## Only what happened, in words up to three times, and a Quota that touched nobody.
func test_the_run_reads_as_a_record() -> void:
	var summaries: Array[SetSummary] = [
		_summary(0, {"wang": [2, 0, 0, 0], "zhao": [0, 0, 0, 0]}),
		_summary(1, {"zhao": [0, 1, 1, 0]}),
		_summary(2, {}),
		_summary(3, {"wang": [3, 4, 0, 1]}),
	]
	var name_of: Callable = func(family: String) -> String: return family.capitalize()
	(
		assert_array(Array(HistoryView.run_lines(summaries, name_of)))
		. is_equal(
			[
				"Quota 1. Wang was fed twice.",
				"Quota 2. Zhao was bombed once, denounced once.",
				"Quota 3. Nothing to record.",
				"Quota 4. Wang was fed three times, bombed 4 times, betrayed once.",
			]
		)
	)


## With no run in progress, there is no "This run" section.
func test_no_run_no_run_section() -> void:
	var screen: VillageHistoryScreen = await _history()
	assert_array(Array(screen.run_lines())).is_empty()
	for node: Node in screen.find_children("*", "Label", true, false):
		assert_str((node as Label).text).is_not_equal(tr("hist.title"))


## The page is one paper sheet across the screen: everything visible sits inside it, in
## dark ink with no halo, 18 px or more, at both sizes, with a run in progress and fifty
## generations behind it, and focus still scrolls to the last record.
func test_the_page_is_one_ink_sheet_at_both_sizes() -> void:
	var entries: Array[HistoryEntry] = []
	for index: int in ProfileData.HISTORY_CAP:
		entries.append(_entry(index + 1, Endings.ENDINGS[index % 7], index % 2 == 0, _keys(2)))
	_write_history(entries)
	_app.new_run(SEED)
	var loop: RunLoop = _app.controller.get("_loop")
	var family: String = loop.state.table[1]
	loop.state.summaries.assign([_summary(0, {family: [2, 0, 1, 0]}), _summary(1, {})])
	for screen_size: Vector2i in SIZES:
		get_tree().root.size = screen_size
		var screen: VillageHistoryScreen = await _history()
		var where: String = str(screen_size)
		assert_int(screen.run_lines().size()).is_equal(2)
		assert_str(screen.run_lines()[1]).is_equal("Quota 2. Nothing to record.")
		var screen_rect: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
		var sheet: Rect2 = screen.sheet().get_global_rect()
		assert_bool(screen_rect.encloses(sheet)).override_failure_message(where).is_true()
		assert_float(sheet.size.x).is_greater(screen_rect.size.x * 0.8)
		_check_inside(screen, sheet.grow(SLACK), where)
		_check_type(screen, where)
		_check_ink(screen, where)
		var records: Array[AgedSheet] = screen.records()
		records[-1].grab_focus()
		await await_idle_frame()
		await await_idle_frame()
		var view: Rect2 = screen.scroll().get_global_rect().grow(SLACK)
		assert_bool(view.encloses(records[-1].get_global_rect())).is_true()


## Every visible control lies inside the sheet: across it always, and down it too unless
## the scroll holds it.
func _check_inside(screen: VillageHistoryScreen, sheet: Rect2, where: String) -> void:
	for node: Node in screen.sheet().find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		var inside: bool = rect.position.x >= sheet.position.x and rect.end.x <= sheet.end.x
		if not screen.scroll().is_ancestor_of(control):
			inside = sheet.encloses(rect)
		(
			assert_bool(inside)
			. override_failure_message("%s %s" % [where, control.get_path()])
			. is_true()
		)


func _check_ink(screen: VillageHistoryScreen, where: String) -> void:
	for node: Node in screen.sheet().find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text.is_empty() or not label.is_visible_in_tree():
			continue
		var ink: Color = label.get_theme_color("font_color")
		var message: String = "%s: %s" % [where, label.text]
		if label.get_parent() is Button:
			continue
		assert_float(ink.get_luminance()).override_failure_message(message).is_less(DARK_INK)
		(
			assert_int(label.get_theme_constant("outline_size"))
			. override_failure_message(message)
			. is_equal(0)
		)


func _settings() -> SettingsScreen:
	var screen: SettingsScreen = _app.show_screen("settings", true)
	await await_idle_frame()
	await await_idle_frame()
	return screen


## A fresh profile: Sunrise is open and chosen; Wheat and Lattice are blank sheets that
## say when they open, and nothing more. With their runs done they wait for their art.
func test_the_card_back_row_at_both_sizes() -> void:
	for runs: int in [0, 5]:
		var data: ProfileData = ProfileData.new()
		data.finished_runs = runs
		Profile.write(Saves.profile_service(), data)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			var screen: SettingsScreen = await _settings()
			var where: String = "%d %s" % [runs, screen_size]
			var row: CardBackRow = screen.card_backs()
			var swatches: Array[AgedSheet] = row.swatches()
			assert_array(row.ids()).is_equal(["sunrise", "", ""])
			assert_bool(swatches[0].choosable).is_true()
			assert_bool(swatches[0].selected).is_true()
			var lines: Array[String] = ["Opens after 2 more runs", "Opens after 5 more runs"]
			if runs == 5:
				lines = ["Not printed yet", "Not printed yet"]
			for index: int in [1, 2]:
				assert_bool(swatches[index].choosable).is_false()
				assert_str(swatches[index].accessibility_name).is_equal(lines[index - 1])
				for label: Node in swatches[index].find_children("*", "Label", true, false):
					var text: String = (label as Label).text
					assert_str(text).is_equal(lines[index - 1])
					assert_bool(text.contains("Wheat") or text.contains("Lattice")).is_false()
			for sheet: AgedSheet in swatches:
				assert_int(sheet.focus_mode).is_equal(Control.FOCUS_ALL)
			_check_type(screen, where)
			var visible: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
			for node: Node in screen.find_children("*", "Control", true, false):
				var control: Control = node as Control
				if control.is_visible_in_tree() and not control is TextureRect:
					(
						assert_bool(visible.encloses(control.get_global_rect()))
						. override_failure_message("%s %s" % [where, control.get_path()])
						. is_true()
					)
			assert_object(swatches[0].find_valid_focus_neighbor(SIDE_RIGHT)).is_same(swatches[1])


## A choice stays only while its design is open: a locked, waiting or unknown one falls
## back to the first, and an accept press on an open swatch chooses it.
func test_a_choice_falls_back_to_the_first() -> void:
	var first: CardBackDef = CardBacks.POOL.backs[0]
	assert_object(CardBacks.chosen("wheat", 0)).is_same(first)
	assert_object(CardBacks.chosen("lattice", 9)).is_same(first)
	assert_object(CardBacks.chosen("no_such_back", 9)).is_same(first)
	var ready: CardBackDef = CardBacks.POOL.back("wheat").duplicate()
	ready.art_pending = false
	assert_bool(CardBacks.is_open(ready, 1)).is_false()
	assert_bool(CardBacks.is_open(ready, 2)).is_true()
	Settings.set_value(CardBacks.SETTING, "lattice")
	assert_object(CardBacks.current()).is_same(first)
	var screen: SettingsScreen = await _settings()
	var sunrise: AgedSheet = screen.card_backs().swatches()[0]
	assert_bool(sunrise.selected).is_true()
	sunrise.chosen.emit()
	assert_str(str(Settings.value(CardBacks.SETTING))).is_equal("sunrise")


## The code-drawn backs on the table take the chosen design, and the seat panels its
## picture.
func test_the_table_draws_the_chosen_design() -> void:
	_app.new_run(SEED)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var beats: DebuffMoments = table.get("_debuff_beats")
	for back: Node in beats.find_children("*", "CardBack", true, false):
		assert_object((back as CardBack).design).is_same(CardBacks.current())
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	var picture: TextureRect = seats[1].get("_back")
	assert_object(picture.texture).is_same(CardBacks.picture(CardBacks.current()))


## Nothing about play changes with the back chosen: the same seed and the same commands
## leave the same run.
func test_play_is_the_same_with_either_back() -> void:
	var states: Array[Dictionary] = []
	for choice: String in ["sunrise", "lattice"]:
		Settings.set_value(CardBacks.SETTING, choice)
		Saves.run_service().delete()
		Saves.profile_service().delete()
		_app.new_run(SEED)
		_app.show_screen("table", true)
		await await_idle_frame()
		var script: ControllerScript = ControllerScript.new()
		for _turn: int in 40:
			if not script.act(_app.controller):
				break
		var state: Dictionary = _app.controller.state_copy().to_dict()
		# The run's ID holds the clock it started at; everything else must match.
		state.erase("identity")
		states.append(state)
	assert_dict(states[0]).is_equal(states[1])

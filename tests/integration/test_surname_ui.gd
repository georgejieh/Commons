extends GdUnitTestSuite
## The surname step (ADR 0028): on a first launch, after the content note and
## before the Arrival page, never with a profile. It opens with the field focused and a
## default from the 24 in it, so one press finishes it in well under 30 seconds; the
## field keeps only Latin letters, at most 12, capitalised; a village family's surname is
## refused in words; the tickets, Random and Confirm finish it from a gamepad alone; the
## profile's first write holds it. Settings shows it and changes it between runs, and
## says why not while a run is saved. The full names fit their pages at 1920x1080 and
## 1280x800 with the longest name the game can make.

const SETTINGS: Array[String] = ["content_note_seen", "reduced_motion"]
const LEAST_TYPE: int = 20
const BOOK: NameBook = preload("res://data/villagers/names.tres")
## The widest surname the field takes: twelve of its widest letters.
const WIDEST_SURNAME: String = "Wmwmwmwmwmwm"
const STEP_SECONDS: float = 30.0

static var _save_path: String = TestFolder.of("test_surname_ui") + "run.json"

var _app: App = null
var _was_size: Vector2i
var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	_was_size = get_tree().root.size
	for key: String in SETTINGS:
		_saved[key] = Settings.value(key)
	Settings.set_value("content_note_seen", true)
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	Saves.profile_service().delete()


func after_test() -> void:
	get_tree().root.size = _was_size
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	Saves.run_service().delete()
	Saves.profile_service().delete()


func _launch() -> App:
	if _app != null and is_instance_valid(_app):
		_app.free()
	_app = AppKit.make(self)
	await await_idle_frame()
	return _app


func _page() -> SurnameScreen:
	return _app.switcher.current() as SurnameScreen


func _longest_given() -> String:
	var longest: String = ""
	for pool: NamePool in BOOK.pools:
		for given: String in pool.names:
			if given.length() > longest.length():
				longest = given
	return longest


func test_the_field_keeps_latin_letters_capitalised_and_twelve_at_most() -> void:
	var cases: Dictionary[String, String] = {
		"zhang": "Zhang",
		"ZHANG": "Zhang",
		"  ye ": "Ye",
		"Zh4ng": "Zhng",
		"o'neil-li": "Oneilli",
		"lü": "L",
		"élan": "Lan",
		"张": "",
		"12 3": "",
		"": "",
		"abcdefghijklmnop": "Abcdefghijkl",
	}
	for typed: String in cases:
		assert_str(Surnames.clean(typed)).override_failure_message(typed).is_equal(cases[typed])


func test_only_a_whole_surname_no_village_family_holds_is_taken() -> void:
	assert_str(Surnames.refusal("")).is_equal(tr("surname.length"))
	assert_str(Surnames.refusal("zhang")).is_equal(tr("surname.length"))
	assert_str(Surnames.refusal("Abcdefghijklm")).is_equal(tr("surname.length"))
	assert_str(Surnames.refusal("Zhang")).is_empty()
	assert_str(Surnames.refusal("Abcdefghijkl")).is_empty()
	for family: FamilyDef in RunDefaults.VILLAGE.families:
		var surname: String = tr(family.name_key)
		var line: String = tr("surname.refused").format({"name": surname})
		assert_str(Surnames.refusal(surname)).is_equal(line)
	assert_str(Surnames.refusal("Wang")).is_equal("The Wang family already lives here.")
	# Youth surnames are among the offered; a youth gets another instead.
	assert_str(Surnames.refusal(tr("villager.youth.hu"))).is_empty()


func test_one_press_finishes_the_step_well_inside_thirty_seconds() -> void:
	var began: int = Time.get_ticks_msec()
	await _launch()
	assert_str(_app.switcher.current_id()).is_equal("surname")
	var page: SurnameScreen = _page()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(page.field())
	var default: String = page.field().text
	assert_array(Surnames.offered()).contains([default])
	await TestInput.tap_key(self, KEY_ENTER)
	assert_str(_app.switcher.current_id()).is_equal("arrival")
	assert_str(_app.arrival.surname).is_equal(default)
	assert_float((Time.get_ticks_msec() - began) / 1000.0).is_less(STEP_SECONDS)
	# Held, not written: the profile's first save comes with the arrival's end or skip.
	assert_bool(ProfileSeen.exists(Saves.profile_service())).is_false()


func test_typing_keeps_only_what_the_field_accepts() -> void:
	await _launch()
	var page: SurnameScreen = _page()
	page.field().select_all()
	await TestInput.tap_key(self, KEY_BACKSPACE)
	await _type("yu 7an-")
	assert_str(page.field().text).is_equal("Yuan")
	await _type("abcdefghijk")
	assert_int(page.field().text.length()).is_equal(Surnames.LONGEST)


func test_a_village_surname_is_refused_and_the_page_stays() -> void:
	await _launch()
	var page: SurnameScreen = _page()
	page.field().text = "Li"
	page.confirm_button().pressed.emit()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("surname")
	assert_str(page.note()).is_equal("The Li family already lives here.")
	page.field().text = ""
	page.confirm()
	assert_str(page.note()).is_equal(tr("surname.length"))


func test_a_gamepad_finishes_with_a_ticket_and_confirm() -> void:
	await _launch()
	var page: SurnameScreen = _page()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(page.tickets()[0])
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	var ticket: SurnameTicket = page.tickets()[1]
	assert_object(get_viewport().gui_get_focus_owner()).is_same(ticket)
	await _pad(JOY_BUTTON_A)
	var chosen: String = ticket.surname
	assert_str(page.field().text).is_equal(chosen)
	assert_bool(ticket.picked).is_true()
	for _row: int in 3:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(page.confirm_button())
	await _pad(JOY_BUTTON_A)
	assert_str(_app.switcher.current_id()).is_equal("arrival")
	assert_str(_app.arrival.surname).is_equal(chosen)


func test_random_picks_one_of_the_offered() -> void:
	await _launch()
	var page: SurnameScreen = _page()
	for _press: int in 8:
		page.random_button().pressed.emit()
		assert_array(Surnames.offered()).contains([page.field().text])


func test_never_shown_with_a_profile() -> void:
	Profile.write(Saves.profile_service(), ProfileData.new())
	await _launch()
	assert_str(_app.switcher.current_id()).is_equal("title")


func test_the_first_profile_write_holds_the_surname() -> void:
	await _launch()
	var page: SurnameScreen = _page()
	page.tickets()[5].pressed.emit()
	var chosen: String = page.field().text
	page.confirm()
	await await_idle_frame()
	var arrival: ArrivalScreen = _app.switcher.current()
	arrival.skip_button().pressed.emit()
	arrival.confirm().skip_button().pressed.emit()
	await await_idle_frame()
	var data: ProfileData = Profile.read(Saves.profile_service())
	assert_str(data.surname).is_equal(chosen)
	assert_array(data.seen).is_equal(["tutorial"])


func test_settings_changes_the_surname_between_runs() -> void:
	var data: ProfileData = ProfileData.new()
	data.seen.append("tutorial")
	data.surname = "Huang"
	Profile.write(Saves.profile_service(), data)
	await _launch()
	var settings: SettingsScreen = _app.show_screen("settings")
	assert_str(settings.name_line()).is_equal("Huang")
	# The name stands on one line with Change beside it, no taller than a button.
	await await_idle_frame()
	var line: Label = settings.family_line
	assert_int(line.get_line_count()).is_equal(1)
	assert_float(line.size.x).is_greater(60.0)
	assert_float(settings.change_button().size.y).is_less(100.0)
	# Controls stands whole at the screen's foot, outside the sheets' scroll.
	var controls: Button = SettingsPanel.controls_button(settings)
	var screen: Rect2 = get_tree().root.get_visible_rect()
	assert_bool(screen.encloses(controls.get_global_rect())).is_true()
	var above: Node = controls.get_parent()
	while above != null and above != settings:
		assert_bool(above is ScrollContainer).is_false()
		above = above.get_parent()
	settings.change_button().pressed.emit()
	await await_idle_frame()
	var page: SurnameScreen = _page()
	assert_str(page.field().text).is_equal("Huang")
	page.field().text = "Zhao"
	page.confirm()
	assert_str(_app.switcher.current_id()).is_equal("surname")
	page.field().text = "Ding"
	page.confirm()
	await await_idle_frame()
	assert_str(_app.switcher.current_id()).is_equal("settings")
	assert_str(Profile.read(Saves.profile_service()).surname).is_equal("Ding")
	assert_str((_app.switcher.current() as SettingsScreen).name_line()).is_equal("Ding")


func test_settings_will_not_change_it_while_a_run_is_saved() -> void:
	var data: ProfileData = ProfileData.new()
	data.seen.append("tutorial")
	data.surname = "Pan"
	Profile.write(Saves.profile_service(), data)
	await _launch()
	assert_bool(_app.new_run(4242, true)).is_true()
	var settings: SettingsScreen = _app.show_screen("settings")
	assert_object(settings.change_button()).is_null()
	var shown: Array[String] = []
	for found: Node in settings.find_children("*", "Label", true, false):
		shown.append((found as Label).text)
	assert_array(shown).contains([tr("settings.name_locked"), "Pan"])


## The field is ink on the village's paper, no clean white box: its boxes draw nothing,
## the paper under it is drawn, and its ink is the tickets' ink, faded by the stage.
func test_the_field_is_written_on_paper() -> void:
	await _launch()
	var page: SurnameScreen = _page()
	var field: LineEdit = page.field()
	for style: String in ["normal", "focus", "read_only"]:
		assert_object(field.get_theme_stylebox(style)).is_instanceof(StyleBoxEmpty)
	var paper: Control = page.field_paper()
	assert_object(field.get_parent()).is_same(paper)
	assert_bool(paper.draw.is_connected(Callable(page, "_draw_paper"))).is_true()
	await await_idle_frame()
	var holds: bool = paper.get_global_rect().encloses(field.get_global_rect())
	var rects: String = "%s %s" % [paper.get_global_rect(), field.get_global_rect()]
	assert_bool(holds).override_failure_message(rects).is_true()
	var ink: Color = field.get_theme_color("font_color")
	assert_float(ink.get_luminance()).is_less(0.2)
	await TestInput.tap_key(self, KEY_ENTER)
	assert_str(_app.switcher.current_id()).is_equal("arrival")


func test_the_page_fits_both_screens() -> void:
	for size: Vector2i in ClipCheck.SIZES:
		get_tree().root.size = size
		await _launch()
		await await_idle_frame()
		var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
		var page: SurnameScreen = _page()
		var parts: Array[Control] = [page.field(), page.confirm_button(), page.random_button()]
		for ticket: SurnameTicket in page.tickets():
			parts.append(ticket)
		for part: Control in parts:
			(
				assert_bool(screen.encloses(part.get_global_rect()))
				. override_failure_message("%s at %s" % [part.name, size])
				. is_true()
			)


## Run setup's header with the longest name a run can give the player, and the ending's
## line, hold it on one line inside the screen, in type 20 px or more.
func test_the_longest_full_name_fits_run_setup_and_the_ending() -> void:
	var longest: String = Surnames.full_name(_longest_given(), WIDEST_SURNAME)
	var data: ProfileData = ProfileData.new()
	data.seen.append("tutorial")
	data.surname = WIDEST_SURNAME
	data.generation = 11
	Profile.write(Saves.profile_service(), data)
	for size: Vector2i in ClipCheck.SIZES:
		get_tree().root.size = size
		await _launch()
		var setup: Control = _app.show_screen("run_setup")
		await await_idle_frame()
		var line: String = tr("setup.named").format({"name": longest, "number": 12})
		await _check_fits(_label_with(setup, setup.call("player_name")), line, size)
		var ending: EndingScreen = await _ending_named(_longest_given(), WIDEST_SURNAME)
		await _check_fits(ending.name_label(), ending.name_label().text, size)
		assert_str(ending.name_label().text).is_equal(longest)


## The dossier names both seated villagers in full, the longest given name included, and
## each name stays inside its sheet and the screen.
func test_the_dossier_holds_the_longest_full_names() -> void:
	Profile.write(Saves.profile_service(), ProfileData.new())
	for size: Vector2i in ClipCheck.SIZES:
		get_tree().root.size = size
		await _launch()
		assert_bool(_app.new_run(97, true)).is_true()
		var loop: RunLoop = _app.controller.run_loop()
		var given: Array[String] = [_longest_given(), BOOK.pools[2].names[30]]
		for seat: int in [1, 2]:
			loop.state.names.given[loop.state.table[seat]] = given[seat - 1]
		var dossier: DossierScreen = _app.show_screen("dossier")
		await await_idle_frame()
		for seat: int in [1, 2]:
			var full: String = _app.controller.seats.seated_full_name(seat)
			assert_str(full).starts_with(given[seat - 1] + " ")
			await _check_fits(_label_with(dossier, full), full, size)


func _ending_named(given: String, surname: String) -> EndingScreen:
	var state: RunState = RunState.new(77)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.year_rounds = 4
	for family: FamilyDef in RunDefaults.VILLAGE.families:
		state.roster.append(RosterEntry.new(family.id))
	state.names.active = true
	state.names.player_surname = surname
	state.names.given[RunNames.PLAYER] = given
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	Saves.run_service().save(record.to_dict())
	_app.resume_to_screen()
	await await_idle_frame()
	await await_idle_frame()
	return _app.switcher.current() as EndingScreen


func _label_with(root: Node, text: String) -> Label:
	for found: Node in root.find_children("*", "Label", true, false):
		if (found as Label).text.contains(text):
			return found as Label
	return null


## Holds text on one line, wholly on screen, inside what holds it, in readable type.
func _check_fits(label: Label, text: String, size: Vector2i) -> void:
	var where: String = "%s at %s" % [text, size]
	assert_object(label).override_failure_message(where).is_not_null()
	if label == null:
		return
	label.text = text
	await await_idle_frame()
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(ClipCheck.SLACK)
	assert_bool(screen.encloses(label.get_global_rect())).override_failure_message(where).is_true()
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	assert_int(font_size).override_failure_message(where).is_greater_equal(LEAST_TYPE)
	var wide: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	assert_float(wide).override_failure_message(where).is_less_equal(label.size.x + ClipCheck.SLACK)


func _type(text: String) -> void:
	for character: String in text:
		for down: bool in [true, false]:
			var key: InputEventKey = InputEventKey.new()
			key.unicode = character.unicode_at(0)
			key.pressed = down
			Input.parse_input_event(key)
			Input.flush_buffered_events()
		await await_idle_frame()


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var press: InputEventJoypadButton = InputEventJoypadButton.new()
		press.button_index = button
		press.pressed = down
		Input.parse_input_event(press)
		Input.flush_buffered_events()
	await await_idle_frame()
	await await_idle_frame()

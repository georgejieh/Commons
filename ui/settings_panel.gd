class_name SettingsPanel
extends RefCounted
## The settings controls on one paper sheet, shared by the settings screen and the
## pause menu. Changes apply at once; the caller saves. A new text size (ADR 0034)
## rebuilds the theme at once, and the sheet's owner builds the sheet again. Two pages
## open from it, each owner showing them its own way: Controls (ADR 0035) and Window
## (WindowSheet), which has a page of its own because this sheet has no room for it at
## the largest text size.

const VOLUMES: Array[String] = ["music_volume", "effects_volume", "voice_volume"]
const TOGGLES: Array[String] = ["reduced_motion", "post_process", "no_flash", "show_hint"]
## Sliders from 0 to 1 under Display.
const DISPLAY_SLIDERS: Array[String] = ["horror_intensity"]
## The text sizes under Display, by the end of their string keys, Standard first.
const TEXT_SIZES: Array[String] = ["standard", "large", "largest"]
## The name of the box for each text size, for the focus and for tests.
const TEXT_SIZE_BOX: String = "TextSize%d"
## The table's paces under Display, by the end of their string keys, slowest first, and
## the name of the box for each.
const PACES: Array[String] = ["slow", "standard", "fast"]
const PACE_SETTING: String = "table_pace"
const PACE_BOX: String = "TablePace%d"
const NAME_SIZE: int = 26
## The least room a setting's name takes; it grows to the widest name, kept on one line,
## so every slider starts at one edge.
const NAME_WIDTH: float = 200.0
## The gap between the sheet's rows at each text size: closer at the larger sizes, so the
## sheet stands whole on the page at every size.
const ROW_GAPS: Array[int] = [18, 14, 6]
## The toggles flow two to a line where they fit.
const TOGGLE_GAP: int = 28
## The names of the tickets that open the Controls and Window pages, for the focus and
## for tests.
const CONTROLS_BUTTON: String = "OpenControls"
const WINDOW_BUTTON: String = "OpenWindow"
const WIDTH: float = 760.0


## With at_table, a line under the text sizes says the table takes a new one at the next
## deal (ADR 0034). Given open_controls and open_window, the sheet ends in the tickets
## that open the two pages.
static func build(
	at_table: bool = false,
	open_controls: Callable = Callable(),
	open_window: Callable = Callable(),
) -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(WIDTH, 0))
	sheet.add_theme_constant_override("separation", ROW_GAPS[TextSize.level()])
	var keys: Array[String] = []
	keys.append_array(VOLUMES)
	keys.append_array(DISPLAY_SLIDERS)
	keys.append_array([TextSize.SETTING, PACE_SETTING])
	var names: float = name_width(keys)
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.audio")))
	for key: String in VOLUMES:
		sheet.add_child(_slider(key, names))
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.display")))
	for key: String in DISPLAY_SLIDERS:
		sheet.add_child(_slider(key, names))
	sheet.add_child(_text_sizes(names, at_table))
	sheet.add_child(choices(PACE_SETTING, names, "settings.table_pace.", PACES, PACE_BOX))
	var toggles: HFlowContainer = HFlowContainer.new()
	toggles.add_theme_constant_override("h_separation", TOGGLE_GAP)
	toggles.add_theme_constant_override("v_separation", ROW_GAPS[TextSize.level()])
	for key: String in TOGGLES:
		toggles.add_child(toggle(key))
	sheet.add_child(toggles)
	if open_controls.is_valid() and open_window.is_valid():
		sheet.add_child(ScreenKit.row(pages(open_controls, open_window)))
	return ScreenKit.card_panel(sheet)


## The Controls ticket and the Window ticket, calling open_controls and open_window.
static func pages(open_controls: Callable, open_window: Callable) -> Array[Control]:
	var controls: Button = ScreenKit.button(
		TranslationServer.translate("controls.open"), CommonsTheme.SECONDARY
	)
	controls.name = CONTROLS_BUTTON
	controls.pressed.connect(open_controls)
	var window: Button = ScreenKit.button(
		TranslationServer.translate("settings.window"), CommonsTheme.SECONDARY
	)
	window.name = WINDOW_BUTTON
	window.pressed.connect(open_window)
	return [controls, window]


## The ticket that opens the Controls page under root, or null.
static func controls_button(root: Node) -> Button:
	return root.find_child(CONTROLS_BUTTON, true, false) as Button


## The ticket that opens the Window page under root, or null.
static func window_button(root: Node) -> Button:
	return root.find_child(WINDOW_BUTTON, true, false) as Button


## A box that turns one setting on and off.
static func toggle(key: String) -> CheckBox:
	var made: CheckBox = CheckBox.new()
	made.text = TranslationServer.translate("settings." + key)
	made.button_pressed = bool(Settings.value(key))
	made.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	return made


## A setting's boxes, one for each value in order, named by the ends of their keys.
static func choices(
	key: String, names: float, prefix: String, ends: Array[String], box_name: String
) -> SettingChoices:
	var made: Dictionary[int, String] = {}
	for value: int in ends.size():
		made[value] = TranslationServer.translate(prefix + ends[value])
	return SettingChoices.new(key, name_label(key, names), made, box_name)


## A named slider from 0 to 1 bound to one setting.
static func _slider(key: String, names: float) -> HBoxContainer:
	var slider: HSlider = HSlider.new()
	slider.custom_minimum_size = Vector2(420, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.value(key))
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
	return ScreenKit.row([name_label(key, names), slider])


## The text size: its name and a box for each size, the chosen one ticked. At the table
## the line saying when the table takes a new size stands close under the boxes, in line
## with them, so it reads as theirs.
static func _text_sizes(names: float, at_table: bool) -> Control:
	assert(TEXT_SIZES.size() == TextSize.count(), "A text size has no name")
	var boxes: SettingChoices = choices(
		TextSize.SETTING, names, "settings.text_size.", TEXT_SIZES, TEXT_SIZE_BOX
	)
	if not at_table:
		return boxes
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.add_child(boxes)
	var note: Label = ScreenKit.styled(
		TranslationServer.translate("settings.text_size.table"), CommonsTheme.CAPTION
	)
	var indent: MarginContainer = MarginContainer.new()
	indent.add_theme_constant_override("margin_left", int(names) + ScreenKit.STYLE.gap)
	indent.add_child(note)
	block.add_child(indent)
	return block


## The box for the text size chosen now under root, for the focus after a rebuild.
static func chosen_text_size(root: Node) -> CheckBox:
	return root.find_child(TEXT_SIZE_BOX % TextSize.level(), true, false) as CheckBox


## After the sheet closes on a new text size, builds the screen under it again, with the
## way back kept. The table is not built again mid-round: what it holds of its own, the
## hand's sort, a need being set, a reading being picked and plays still to be acted out,
## would be lost, so it takes the new size the next time it opens (at the next Set, a
## swap or a resume). Neither is the arrival's scripted evening; its pieces take the size
## at the next screen.
static func rebuild_screen(app: App) -> void:
	if app.arrival.is_running() or app.switcher.current_id() == app.table_id():
		return
	app.reopen()


## A setting's name, beside its control, on one line, names wide.
static func name_label(key: String, names: float) -> Label:
	var label: Label = ScreenKit.styled(
		TranslationServer.translate("settings." + key), CommonsTheme.TITLE
	)
	label.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(names, 0)
	return label


## The room the names of keys take: the widest of them at the chosen size, or NAME_WIDTH.
static func name_width(keys: Array[String]) -> float:
	var widest: float = NAME_WIDTH
	for key: String in keys:
		var words: String = TranslationServer.translate("settings." + key)
		var shown: Vector2 = CommonsTheme.BOLD.get_string_size(
			words, HORIZONTAL_ALIGNMENT_LEFT, -1, TextSize.px(NAME_SIZE)
		)
		widest = maxf(widest, ceilf(shown.x))
	return widest

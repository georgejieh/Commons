class_name SettingsPanel
extends RefCounted
## The settings controls on one paper sheet, shared by the settings screen and the
## pause menu. Changes apply at once; the caller saves. A new text size (ADR 0034)
## rebuilds the theme at once, and the sheet's owner builds the sheet again. At its foot a
## ticket opens the Controls page (ADR 0035), which each owner shows its own way.

const VOLUMES: Array[String] = ["music_volume", "effects_volume", "voice_volume"]
const TOGGLES: Array[String] = ["reduced_motion", "post_process", "no_flash"]
## Sliders from 0 to 1 under Display.
const DISPLAY_SLIDERS: Array[String] = ["horror_intensity"]
## The text sizes under Display, by the end of their string keys, Standard first.
const TEXT_SIZES: Array[String] = ["standard", "large", "largest"]
## The name of the box for each text size, for the focus and for tests.
const TEXT_SIZE_BOX: String = "TextSize%d"
const NAME_SIZE: int = 26
## The name of the ticket that opens the Controls page, for the focus and for tests.
const CONTROLS_BUTTON: String = "OpenControls"


## With at_table, a line under the text sizes says the table takes a new one at the next
## deal (ADR 0034). With open_controls, the sheet ends in a Controls ticket that calls it.
static func build(at_table: bool = false, open_controls: Callable = Callable()) -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(760, 0))
	sheet.add_theme_constant_override("separation", 18)
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.audio")))
	for key: String in VOLUMES:
		sheet.add_child(_slider(key))
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.display")))
	for key: String in DISPLAY_SLIDERS:
		sheet.add_child(_slider(key))
	sheet.add_child(_text_sizes())
	if at_table:
		var note: Label = ScreenKit.styled(
			TranslationServer.translate("settings.text_size.table"), CommonsTheme.CAPTION
		)
		sheet.add_child(note)
	for key: String in TOGGLES:
		var toggle: CheckBox = CheckBox.new()
		toggle.text = TranslationServer.translate("settings." + key)
		toggle.button_pressed = bool(Settings.value(key))
		toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
		sheet.add_child(toggle)
	if open_controls.is_valid():
		var controls: Button = ScreenKit.button(
			TranslationServer.translate("controls.open"), CommonsTheme.SECONDARY
		)
		controls.name = CONTROLS_BUTTON
		controls.pressed.connect(open_controls)
		sheet.add_child(controls)
	return ScreenKit.card_panel(sheet)


## The ticket that opens the Controls page under root, or null.
static func controls_button(root: Node) -> Button:
	return root.find_child(CONTROLS_BUTTON, true, false) as Button


## A named slider from 0 to 1 bound to one setting.
static func _slider(key: String) -> HBoxContainer:
	var slider: HSlider = HSlider.new()
	slider.custom_minimum_size = Vector2(420, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.value(key))
	slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
	return ScreenKit.row([_name(key), slider])


## The text size: its name and a box for each size, the chosen one ticked. The boxes are
## one group, so arrows move between them and accept picks one, like the sheet's toggles.
static func _text_sizes() -> HBoxContainer:
	assert(TEXT_SIZES.size() == TextSize.count(), "A text size has no name")
	var group: ButtonGroup = ButtonGroup.new()
	var row: Array[Control] = [_name(TextSize.SETTING)]
	for level: int in TEXT_SIZES.size():
		var choice: CheckBox = CheckBox.new()
		choice.name = TEXT_SIZE_BOX % level
		choice.button_group = group
		choice.text = TranslationServer.translate("settings.text_size." + TEXT_SIZES[level])
		choice.button_pressed = level == TextSize.level()
		choice.toggled.connect(
			func(on: bool) -> void:
				if on and level != TextSize.level():
					Settings.set_value(TextSize.SETTING, level)
		)
		row.append(choice)
	return ScreenKit.row(row)


## The box for the text size chosen now under root, for the focus after a rebuild.
static func chosen_text_size(root: Node) -> CheckBox:
	return root.find_child(TEXT_SIZE_BOX % TextSize.level(), true, false) as CheckBox


## After the sheet closes on a new text size, builds the screen under it again, with the
## way back kept. The table is not built again mid-round: what it holds of its own, the
## hand's sort, a need being set, a reading being picked and plays still to be acted out,
## would be lost, so it takes the new size the next time it opens (at the next Set, a
## swap or a resume). Neither is the arrival's scripted evening; its pieces take the size
## at the next screen.
static func rebuild_screen(app: DemoApp) -> void:
	if app.arrival.is_running() or app.switcher.current_id() == app.table_id():
		return
	var screen: Node = app.switcher.reload()
	if screen.has_method("open"):
		screen.call("open", app)
	app.arrival.shown(app.switcher.current_id())


## A setting's name, beside its control.
static func _name(key: String) -> Label:
	var name: Label = ScreenKit.styled(
		TranslationServer.translate("settings." + key), CommonsTheme.TITLE
	)
	name.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	name.custom_minimum_size = Vector2(200, 0)
	return name

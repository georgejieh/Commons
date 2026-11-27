class_name WindowSheet
extends RefCounted
## The Window page's sheet, opened from the settings sheet on the settings screen and in
## the pause menu: the window's mode, its size and vertical sync (DisplayWindow). A size
## can be picked only for a window, and only those the screen has room for are offered.

## The window modes by the end of their string keys, in DisplayWindow.MODES's order.
const MODES: Array[String] = ["windowed", "borderless", "exclusive"]
## The name of the box for each window mode, filled with its index, for the focus and for tests.
const MODE_BOX: String = "WindowMode%d"
## The name of the box for each window size, filled with its index, for the focus and for tests.
const SIZE_BOX: String = "WindowSize%d"


## The Window page's sheet, with its mode, size and vertical sync rows.
static func build() -> Control:
	assert(MODES.size() == DisplayWindow.MODES.size(), "A window mode has no name")
	var sheet: VBoxContainer = ScreenKit.card(Vector2(SettingsPanel.WIDTH, 0))
	sheet.add_theme_constant_override("separation", SettingsPanel.ROW_GAPS[TextSize.level()])
	var keys: Array[String] = [DisplayWindow.MODE, DisplayWindow.SIZE]
	var names: float = SettingsPanel.name_width(keys)
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.window")))
	sheet.add_child(
		SettingsPanel.choices(DisplayWindow.MODE, names, "settings.window_mode.", MODES, MODE_BOX)
	)
	sheet.add_child(_sizes(names))
	sheet.add_child(SettingsPanel.toggle(DisplayWindow.VSYNC))
	return ScreenKit.card_panel(sheet)


## The box for the window mode chosen now under root, for the focus.
static func chosen_mode(root: Node) -> CheckBox:
	return root.find_child(MODE_BOX % DisplayWindow.mode_chosen(), true, false) as CheckBox


static func _sizes(names: float) -> SettingChoices:
	var choices: Dictionary[int, String] = {}
	var words: String = TranslationServer.translate("settings.window_size.choice")
	for index: int in DisplayWindow.offered(DisplayWindow.usable_screen()):
		var size: Vector2i = DisplayWindow.PARAMS.window_sizes[index]
		choices[index] = words.format({"width": size.x, "height": size.y})
	var label: Label = SettingsPanel.name_label(DisplayWindow.SIZE, names)
	return SettingChoices.new(DisplayWindow.SIZE, label, choices, SIZE_BOX, _windowed)


static func _windowed() -> bool:
	return DisplayWindow.mode_chosen() == DisplayWindow.WINDOWED

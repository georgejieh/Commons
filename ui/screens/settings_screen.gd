class_name SettingsScreen
extends Control
## Volumes, motion and the print pass, on one sheet. Changes apply at once and save on
## the way back.

const VOLUMES: Array[String] = ["music_volume", "effects_volume", "voice_volume"]
const TOGGLES: Array[String] = ["reduced_motion", "post_process"]


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("settings.eyebrow"), tr("settings.title")))
	var sheet: VBoxContainer = ScreenKit.card(Vector2(760, 0))
	sheet.add_theme_constant_override("separation", 18)
	sheet.add_child(ScreenKit.eyebrow(tr("settings.audio")))
	for key: String in VOLUMES:
		var slider: HSlider = HSlider.new()
		slider.custom_minimum_size = Vector2(420, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.value(key))
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
		var name: Label = ScreenKit.styled(tr("settings." + key), CommonsTheme.TITLE)
		name.add_theme_font_size_override("font_size", 26)
		name.custom_minimum_size = Vector2(200, 0)
		sheet.add_child(ScreenKit.row([name, slider]))
	sheet.add_child(ScreenKit.eyebrow(tr("settings.display")))
	for key: String in TOGGLES:
		var toggle: CheckBox = CheckBox.new()
		toggle.text = tr("settings." + key)
		toggle.button_pressed = bool(Settings.value(key))
		toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
		sheet.add_child(toggle)
	column.add_child(ScreenKit.card_panel(sheet))
	var back: Button = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(
		func() -> void:
			Settings.save()
			app.back()
	)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()

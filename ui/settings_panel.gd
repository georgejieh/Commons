class_name SettingsPanel
extends RefCounted
## The settings controls on one paper sheet, shared by the settings screen and the
## pause menu. Changes apply at once; the caller saves.

const VOLUMES: Array[String] = ["music_volume", "effects_volume", "voice_volume"]
const TOGGLES: Array[String] = ["reduced_motion", "post_process"]


static func build() -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(760, 0))
	sheet.add_theme_constant_override("separation", 18)
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.audio")))
	for key: String in VOLUMES:
		var slider: HSlider = HSlider.new()
		slider.custom_minimum_size = Vector2(420, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.value(key))
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
		var name: Label = ScreenKit.styled(
			TranslationServer.translate("settings." + key), CommonsTheme.TITLE
		)
		name.add_theme_font_size_override("font_size", 26)
		name.custom_minimum_size = Vector2(200, 0)
		sheet.add_child(ScreenKit.row([name, slider]))
	sheet.add_child(ScreenKit.eyebrow(TranslationServer.translate("settings.display")))
	for key: String in TOGGLES:
		var toggle: CheckBox = CheckBox.new()
		toggle.text = TranslationServer.translate("settings." + key)
		toggle.button_pressed = bool(Settings.value(key))
		toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
		sheet.add_child(toggle)
	return ScreenKit.card_panel(sheet)

class_name SettingsScreen
extends Control
## Volumes and reduced motion. Changes apply at once and save when you go back.

const VOLUMES: Array[String] = ["music_volume", "effects_volume", "voice_volume"]


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.label(tr("settings.title"), 72, ScreenKit.RED))
	for key: String in VOLUMES:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_child(ScreenKit.label(tr("settings." + key), 28))
		var slider: HSlider = HSlider.new()
		slider.custom_minimum_size = Vector2(400, 32)
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.value(key))
		slider.value_changed.connect(func(value: float) -> void: Settings.set_value(key, value))
		row.add_child(slider)
		column.add_child(row)
	var motion: CheckBox = CheckBox.new()
	motion.text = tr("settings.reduced_motion")
	motion.add_theme_font_size_override("font_size", 28)
	motion.button_pressed = bool(Settings.value("reduced_motion"))
	motion.toggled.connect(func(on: bool) -> void: Settings.set_value("reduced_motion", on))
	column.add_child(motion)
	var print_pass: CheckBox = CheckBox.new()
	print_pass.text = tr("settings.post_process")
	print_pass.add_theme_font_size_override("font_size", 28)
	print_pass.button_pressed = bool(Settings.value("post_process"))
	print_pass.toggled.connect(func(on: bool) -> void: Settings.set_value("post_process", on))
	column.add_child(print_pass)
	var back: Button = ScreenKit.button(tr("settings.back"))
	back.pressed.connect(
		func() -> void:
			Settings.save()
			app.back()
	)
	column.add_child(back)
	back.grab_focus()

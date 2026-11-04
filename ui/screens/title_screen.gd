class_name TitleScreen
extends Control
## The title: start a new demo run, continue a saved one, or open the settings.


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.label(tr("game.title"), 120, ScreenKit.RED))
	column.add_child(ScreenKit.label(tr("title.subtitle"), 28))
	var new_run: Button = ScreenKit.button(tr("title.new_run"), ScreenKit.RED)
	new_run.pressed.connect(
		func() -> void:
			app.new_run(int(Time.get_unix_time_from_system()))
			app.show_screen("set_intro", true)
	)
	column.add_child(new_run)
	if app.has_saved_run():
		var resume: Button = ScreenKit.button(tr("title.continue"))
		resume.pressed.connect(func() -> void: app.resume_to_screen())
		column.add_child(resume)
	var settings: Button = ScreenKit.button(tr("title.settings"))
	settings.pressed.connect(func() -> void: app.show_screen("settings"))
	column.add_child(settings)
	var quit: Button = ScreenKit.button(tr("title.quit"))
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	new_run.grab_focus()

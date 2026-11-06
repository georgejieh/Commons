class_name TitleScreen
extends Control
## The title: start a new run through run setup, continue a saved one, or open the
## collection, village history or settings.


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.title_night)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(ScreenKit.eyebrow(tr("title.eyebrow")))
	var title: Label = ScreenKit.styled(tr("game.title"), CommonsTheme.HEADLINE)
	title.add_theme_font_size_override("font_size", 168)
	title.add_theme_color_override("font_color", ScreenKit.GOLD)
	title.add_theme_color_override("font_outline_color", ScreenKit.INK)
	title.add_theme_constant_override("outline_size", 20)
	column.add_child(title)
	var subtitle: Label = ScreenKit.styled(tr("title.subtitle"), CommonsTheme.TITLE)
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", ScreenKit.STYLE.paper)
	subtitle.add_theme_color_override("font_outline_color", ScreenKit.INK)
	column.add_child(subtitle)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	var new_run: Button = ScreenKit.button(tr("title.new_run"), CommonsTheme.PRIMARY)
	new_run.pressed.connect(func() -> void: app.show_screen("run_setup"))
	column.add_child(new_run)
	if app.has_saved_run():
		var resume: Button = ScreenKit.button(tr("title.continue"))
		resume.pressed.connect(func() -> void: app.resume_to_screen())
		column.add_child(resume)
	var settings: Button = ScreenKit.button(tr("title.settings"), CommonsTheme.GHOST)
	settings.pressed.connect(func() -> void: app.show_screen("settings"))
	var quit: Button = ScreenKit.button(tr("title.quit"), CommonsTheme.GHOST)
	quit.pressed.connect(func() -> void: get_tree().quit())
	var collection: Button = ScreenKit.button(tr("title.collection"), CommonsTheme.GHOST)
	collection.pressed.connect(func() -> void: app.show_screen("collection"))
	var history: Button = ScreenKit.button(tr("title.history"), CommonsTheme.GHOST)
	history.pressed.connect(func() -> void: app.show_screen("village_history"))
	column.add_child(ScreenKit.row([collection, history, settings, quit]))
	ScreenKit.reveal(column)
	new_run.grab_focus()

class_name SettingsScreen
extends Control
## Volumes, motion and the print pass, on one sheet. Changes apply at once and save on
## the way back.


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("settings.eyebrow"), tr("settings.title")))
	column.add_child(SettingsPanel.build())
	var back: Button = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(
		func() -> void:
			Settings.save()
			app.back()
	)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()

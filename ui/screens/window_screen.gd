class_name WindowScreen
extends Control
## The Window page at the title, opened from the settings screen: the page's header over
## the WindowSheet, and Back, which Escape also presses. Changes apply at once and save
## on the way back, as on the settings screen.

var _app: App = null
var _back: Button = null


## Builds the page over WindowSheet, with Back; call once when the screen is served.
func open(app: App) -> void:
	_app = app
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.header(tr("settings.eyebrow"), tr("settings.window")))
	var sheet: Control = WindowSheet.build()
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(sheet)
	_back = ScreenKit.button(tr("settings.back"), CommonsTheme.PRIMARY)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(_leave)
	column.add_child(_back)
	ScreenKit.reveal(column)
	WindowSheet.chosen_mode(self).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if ScreenKit.take_cancel(self, event):
		_leave()


## Back, for tests and the playtest.
func back_button() -> Button:
	return _back


func _leave() -> void:
	Settings.save()
	_app.back()

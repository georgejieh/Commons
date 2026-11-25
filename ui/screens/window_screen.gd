class_name WindowScreen
extends Control
## The Window page at the title, opened from the settings screen: the page's header over
## the WindowSheet, and Back, which Escape also presses. Changes apply at once and save
## on the way back, as on the settings screen.

var _app: DemoApp = null
var _back: Button = null


func open(app: DemoApp) -> void:
	_app = app
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
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
	if _back != null and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


## Back, for tests and the playtest.
func back_button() -> Button:
	return _back


func _leave() -> void:
	Settings.save()
	_app.back()

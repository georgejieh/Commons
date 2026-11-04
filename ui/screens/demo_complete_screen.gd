class_name DemoCompleteScreen
extends Control
## The demo's last screen.


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(ScreenKit.label(tr("demo.done"), 80, ScreenKit.RED))
	column.add_child(ScreenKit.label(tr("demo.done_text"), 30))
	var back: Button = ScreenKit.button(tr("demo.to_title"))
	back.pressed.connect(func() -> void: app.show_screen("title", true))
	column.add_child(back)
	back.grab_focus()

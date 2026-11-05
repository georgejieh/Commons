class_name DemoCompleteScreen
extends Control
## The demo's last screen.


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.title)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(ScreenKit.header(tr("demo.eyebrow"), tr("demo.done")))
	column.add_child(ScreenKit.styled(tr("demo.done_text"), CommonsTheme.TITLE))
	var back: Button = ScreenKit.button(tr("demo.to_title"), CommonsTheme.PRIMARY)
	back.pressed.connect(func() -> void: app.show_screen("title", true))
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()

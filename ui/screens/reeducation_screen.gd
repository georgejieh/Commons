class_name ReeducationScreen
extends Control
## Reeducation (P4.1): served in place of the store after mid Denunciation. The plot is
## already emptied and a Cadre exchanged by the time this opens; it only reports that.


func open(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.watchers)
	var heading: Control = ScreenKit.header(tr("reed.eyebrow"), tr("reed.title"))
	sheet.add_child(heading)
	sheet.add_child(ScreenKit.label(tr("reed.body"), 26))
	var next: Button = ScreenKit.button(tr("reed.continue"), CommonsTheme.PRIMARY)
	next.pressed.connect(_leave.bind(app))
	sheet.add_child(next)
	ScreenKit.reveal(sheet)
	UiMotion.stamp(heading)
	next.grab_focus()


## Back to the run. Opened from anywhere else, as the screen tests do, it just goes back.
func _leave(app: DemoApp) -> void:
	if app.controller.awaiting() != RunController.AWAIT_REEDUCATION:
		app.back()
		return
	app.controller.leave_reeducation()
	var over: bool = app.controller.awaiting() == RunController.AWAIT_RUN_OVER
	app.show_screen("year_summary" if over else "set_intro", true)

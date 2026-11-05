class_name ReeducationScreen
extends Control
## Reeducation (P3B.9): shown when mid Denunciation sends you away for a Set. Nothing
## sends you there until the meters arrive in P4.1.


func open(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.watchers)
	var heading: Control = ScreenKit.header(tr("reed.eyebrow"), tr("reed.title"))
	sheet.add_child(heading)
	sheet.add_child(ScreenKit.label(tr("reed.body"), 26))
	var next: Button = ScreenKit.button(tr("reed.continue"), CommonsTheme.PRIMARY)
	next.pressed.connect(app.back)
	sheet.add_child(next)
	ScreenKit.reveal(sheet)
	UiMotion.stamp(heading)
	next.grab_focus()

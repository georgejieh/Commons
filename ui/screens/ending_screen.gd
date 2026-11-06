class_name EndingScreen
extends Control
## The end of a run (P3B.9): your final class, both meters and who sat at the table.
## The six endings and their epilogues arrive with P4.13.


func open(app: DemoApp) -> void:
	var state: RunState = app.controller.state_copy()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	var landlord: bool = state.landlord_seat == 0
	var heading: Control = ScreenKit.header(
		tr("end.eyebrow"), tr("end.landlord" if landlord else "end.peasant")
	)
	sheet.add_child(heading)
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("end.famine"), state.famine),
		ScreenKit.stat(tr("end.denunciation"), state.denunciation),
		ScreenKit.stat(tr("end.coupons"), state.coupons),
	]
	sheet.add_child(ScreenKit.row(tiles, 20))
	sheet.add_child(ScreenKit.eyebrow(tr("end.table")))
	var names: PackedStringArray = []
	for seat: int in range(1, Seats.COUNT):
		names.append(app.seat_name(seat))
	sheet.add_child(ScreenKit.label(", ".join(names), 24))
	var home: Button = ScreenKit.button(tr("end.to_title"), CommonsTheme.PRIMARY)
	home.pressed.connect(func() -> void: app.show_screen("title", true))
	sheet.add_child(home)
	ScreenKit.reveal(sheet)
	UiMotion.stamp(heading)
	home.grab_focus()

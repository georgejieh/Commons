class_name YearSummaryScreen
extends Control
## The end of the demo's one Year: what you hold and how the village stands.


func open(app: DemoApp) -> void:
	var state: RunState = app.controller.state_copy()
	var column: VBoxContainer = ScreenKit.page(self)
	var heading: Control = ScreenKit.header(
		tr("year.eyebrow"), tr("year.title").format({"year": state.year})
	)
	column.add_child(heading)
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("year.coupons_label"), state.coupons),
		ScreenKit.stat(tr("year.cadres_label"), state.inventory.cadres.size()),
		ScreenKit.stat(tr("year.famine_label"), state.famine),
		ScreenKit.stat(tr("year.denunciation_label"), state.denunciation),
	]
	column.add_child(ScreenKit.row(tiles, 20))
	var next: Button = ScreenKit.button(tr("year.next"), CommonsTheme.PRIMARY)
	next.pressed.connect(func() -> void: app.show_screen("demo_complete", true))
	column.add_child(next)
	ScreenKit.reveal(column)
	UiMotion.stamp(heading)
	next.grab_focus()

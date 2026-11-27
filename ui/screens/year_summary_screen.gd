class_name YearSummaryScreen
extends Control
## The end of the demo's one Year: what you hold and how the village stands.


## Builds the demo's Year summary, ending in a button on to the demo's close; call once when served.
func open(app: App) -> void:
	var state: RunView = app.controller.run
	var column: VBoxContainer = SheetPad.column(
		ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	)
	var heading: Control = ScreenKit.header(
		tr("year.eyebrow"), tr("year.title").format({"year": state.year()})
	)
	column.add_child(heading)
	var tiles: Array[Control] = [
		StatTile.figure(tr("year.coupons_label"), state, RunCorrections.COUPONS, state.coupons()),
		StatTile.rolling(tr("year.cadres_label"), state.held_cadres().size()),
		StatTile.figure(tr("year.famine_label"), state, RunCorrections.FAMINE, state.famine()),
		StatTile.figure(
			tr("year.denunciation_label"), state, RunCorrections.DENUNCIATION, state.denunciation()
		),
	]
	column.add_child(ScreenKit.row(tiles, 20))
	var next: Button = ScreenKit.button(tr("year.next"), CommonsTheme.PRIMARY)
	next.pressed.connect(func() -> void: app.show_screen(ScreenId.DEMO_COMPLETE, true))
	column.add_child(next)
	ScreenKit.reveal(column)
	UiMotion.stamp(heading)
	next.grab_focus()

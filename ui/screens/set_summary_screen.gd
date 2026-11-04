class_name SetSummaryScreen
extends Control
## After a Set: whether the Quota was met, what it paid or cost, then on to the store
## or, after the run's last Set, to the Year's summary.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var met: bool = state.set_progress >= controller.target()
	var column: VBoxContainer = ScreenKit.page(self)
	var verdict: Control = ScreenKit.header(
		tr("set.type.%d" % state.set_type), tr("summary.met" if met else "summary.missed")
	)
	column.add_child(verdict)
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("summary.scored"), state.set_progress),
		ScreenKit.stat(tr("summary.target"), controller.target(), controller.target()),
		ScreenKit.stat(tr("summary.coupons_label"), state.coupons),
		ScreenKit.stat(tr("summary.famine_label"), state.famine),
	]
	column.add_child(ScreenKit.row(tiles, 20))
	var last: bool = controller.is_last_set()
	var next: Button = ScreenKit.button(
		tr("summary.to_year" if last else "summary.to_store"), CommonsTheme.PRIMARY
	)
	next.pressed.connect(
		func() -> void:
			controller.finish_set()
			app.show_screen("year_summary" if last else "store", true)
	)
	column.add_child(next)
	ScreenKit.reveal(column)
	UiMotion.stamp(verdict)
	next.grab_focus()

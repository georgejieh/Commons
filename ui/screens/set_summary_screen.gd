class_name SetSummaryScreen
extends Control
## After a Set: whether the Quota was met, what it paid or cost, then on to the store
## or, after the run's last Set, to the Year's summary.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var met: bool = state.set_progress >= controller.target()
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(
		ScreenKit.label(tr("summary.met" if met else "summary.missed"), 80, ScreenKit.RED)
	)
	column.add_child(
		ScreenKit.label(
			tr("summary.progress").format(
				{
					"progress": Strings.score(state.set_progress),
					"target": Strings.score(controller.target())
				}
			),
			34
		)
	)
	column.add_child(ScreenKit.label(tr("summary.coupons").format({"count": state.coupons}), 28))
	column.add_child(ScreenKit.label(tr("summary.famine").format({"value": state.famine}), 28))
	var last: bool = controller.is_last_set()
	var next: Button = ScreenKit.button(
		tr("summary.to_year" if last else "summary.to_store"), ScreenKit.RED
	)
	next.pressed.connect(
		func() -> void:
			controller.finish_set()
			app.show_screen("year_summary" if last else "store", true)
	)
	column.add_child(next)
	next.grab_focus()

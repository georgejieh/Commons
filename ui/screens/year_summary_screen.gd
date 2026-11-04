class_name YearSummaryScreen
extends Control
## The end of the demo's one Year: how each Quota went and what you hold.


func open(app: DemoApp) -> void:
	var state: RunState = app.controller.state_copy()
	var column: VBoxContainer = ScreenKit.page(self)
	column.add_child(
		ScreenKit.label(tr("year.title").format({"year": state.year}), 80, ScreenKit.RED)
	)
	column.add_child(ScreenKit.label(tr("year.coupons").format({"count": state.coupons}), 30))
	column.add_child(ScreenKit.label(tr("year.famine").format({"value": state.famine}), 30))
	column.add_child(
		ScreenKit.label(tr("year.cadres").format({"count": state.inventory.cadres.size()}), 30)
	)
	var next: Button = ScreenKit.button(tr("year.next"), ScreenKit.RED)
	next.pressed.connect(func() -> void: app.show_screen("demo_complete", true))
	column.add_child(next)
	next.grab_focus()

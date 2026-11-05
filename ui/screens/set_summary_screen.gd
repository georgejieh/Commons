class_name SetSummaryScreen
extends Control
## After a Set: whether the Quota was met, what it paid or cost, then on to the store
## or, after the run's last Set, to the Year's summary.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var met: bool = state.set_progress >= controller.target()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.notice_wall)
	var verdict: Control = ScreenKit.header(
		tr("set.type.%d" % state.set_type), tr("summary.met" if met else "summary.missed")
	)
	sheet.add_child(verdict)
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("summary.scored"), state.set_progress),
		ScreenKit.stat(tr("summary.target"), controller.target(), controller.target()),
		ScreenKit.stat(tr("summary.coupons_label"), state.coupons),
		ScreenKit.stat(tr("summary.famine_label"), state.famine),
	]
	sheet.add_child(ScreenKit.row(tiles, 20))
	sheet.add_child(_consequence(controller, met, state.famine))
	var last: bool = controller.is_last_set()
	var next: Button = ScreenKit.button(
		tr("summary.to_year" if last else "summary.to_store"), CommonsTheme.PRIMARY
	)
	next.pressed.connect(
		func() -> void:
			controller.finish_set()
			app.show_screen(app.screen_for(controller.awaiting()), true)
	)
	sheet.add_child(next)
	ScreenKit.reveal(sheet)
	UiMotion.stamp(verdict)
	next.grab_focus()


## What the result means: the coupons it paid, or the Famine it cost and what Famine does.
func _consequence(controller: RunController, met: bool, famine: int) -> Label:
	var text: String
	if met:
		text = Strings.count("summary.paid", controller.quota_reward())
	else:
		text = tr("summary.cost").format({"rise": controller.famine_per_miss(), "famine": famine})
	var line: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	line.add_theme_font_size_override("font_size", 26)
	line.add_theme_color_override("font_color", ScreenKit.INK if met else ScreenKit.RED)
	return line

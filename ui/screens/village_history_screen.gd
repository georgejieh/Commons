class_name VillageHistoryScreen
extends Control
## Village history (P3B.9): what each Quota of this run left behind, per villager.
## History across runs arrives with the profile save (P4.14).


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	column.add_child(ScreenKit.header(tr("hist.eyebrow"), tr("hist.title"), ScreenKit.GOLD))
	var lines: PackedStringArray = history_lines(app)
	if lines.is_empty():
		lines.append(tr("hist.empty"))
	for text: String in lines:
		column.add_child(ScreenKit.label(text, 22, ScreenKit.STYLE.paper))
	var back: Button = ScreenKit.button(tr("hist.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


## One heading per Quota, then one line per villager it touched.
static func history_lines(app: DemoApp) -> PackedStringArray:
	var lines: PackedStringArray = []
	if not app.controller.has_run():
		return lines
	var state: RunState = app.controller.state_copy()
	for summary: SetSummary in state.summaries:
		if summary.counts.is_empty():
			continue
		var heading: String = TranslationServer.translate("hist.set")
		lines.append(heading.format({"number": summary.set_number + 1}))
		for family: String in summary.counts:
			lines.append(_row(app, state, summary, family))
	return lines


static func _row(app: DemoApp, state: RunState, summary: SetSummary, family: String) -> String:
	var seat: int = state.table.find(family)
	var fields: Dictionary = {
		"name": app.seat_name(seat) if seat > 0 else family,
		"fed": summary.count(family, SetSummary.Kind.FED),
		"bombed": summary.count(family, SetSummary.Kind.BOMBED),
		"denounced": summary.count(family, SetSummary.Kind.DENOUNCED),
		"betrayed": summary.count(family, SetSummary.Kind.BETRAYED),
	}
	return TranslationServer.translate("hist.row").format(fields)

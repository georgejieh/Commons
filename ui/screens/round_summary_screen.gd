class_name RoundSummaryScreen
extends Control
## The last finished round (P3B.9): which side won, your score, your Commons share and
## where the Quota stands. Opened from the table's menu; Back returns to the table.


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.notice_wall)
	var last: Dictionary = last_round(controller.set_events())
	var title_key: String = "round.none"
	if not last.is_empty():
		title_key = "round.won" if bool(last["won"]) else "round.lost"
	var eyebrow: String = tr("round.eyebrow").format({"round": maxi(1, state.round_index)})
	sheet.add_child(ScreenKit.header(eyebrow, tr(title_key)))
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("round.score"), float(last.get("score", 0.0))),
		ScreenKit.stat(tr("round.share"), float(last.get("share", 0))),
		ScreenKit.stat(tr("round.progress"), state.set_progress),
	]
	sheet.add_child(ScreenKit.row(tiles, 20))
	var back: Button = ScreenKit.button(tr("round.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	sheet.add_child(back)
	ScreenKit.reveal(sheet)
	back.grab_focus()


## The player's result in the Set's last finished round, or empty when none has.
static func last_round(events: Array[RunEvent]) -> Dictionary:
	var result: Dictionary = {}
	var finished: Dictionary = {}
	var landlord: int = Seats.NONE
	for event: RunEvent in events:
		if event.round_event != null:
			var played: RoundEvent = event.round_event
			if played.type == RoundEvent.Type.ROUND_STARTED:
				landlord = played.seat
				result = {}
			elif played.type == RoundEvent.Type.ROUND_ENDED:
				result["won"] = (played.seat == landlord) == (landlord == 0)
		elif event.type == RunEvent.Type.ROUND_SCORED and event.seat == 0:
			result["score"] = event.amount
		elif event.type == RunEvent.Type.SHARE_PAID and event.seat == 0:
			result["share"] = event.value
		if result.has("won"):
			finished = result
	return finished

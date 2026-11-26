class_name RoundSummaryScreen
extends Control
## The last finished round: which side won, your score, your Commons share and
## where the Quota stands. Opened from the table's menu; Back returns to the table.

## The stake's and the bank's lines, at Standard.
const LINE_SIZE: int = 24


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunView = controller.run
	var sheet: VBoxContainer = SheetPad.over_board(self, SheetPad.BOARD_WIDTH)
	var last: Dictionary = last_round(controller.set_events())
	var title_key: String = "round.none"
	if not last.is_empty():
		title_key = "round.won" if bool(last["won"]) else "round.lost"
	var eyebrow: String = tr("round.eyebrow").format({"round": maxi(1, state.round_index())})
	sheet.add_child(ScreenKit.header(eyebrow, tr(title_key)))
	var tiles: Array[Control] = [
		ScreenKit.stat(tr("round.score"), float(last.get("score", 0.0))),
		ScreenKit.stat(tr("round.share"), float(last.get("share", 0))),
		ScreenKit.figure_stat(
			tr("round.progress"), state, RunCorrections.PROGRESS, state.set_progress()
		),
	]
	sheet.add_child(ScreenKit.row(tiles, 20))
	# Overfulfillment's stake is part of the result: the bank multiplied, or voided.
	if last.has("stake"):
		sheet.add_child(ScreenKit.label(stake_line(last), LINE_SIZE, ScreenKit.RED))
	# What debuffs took from the bank is part of the result too (ADR 0023).
	for line: String in debuff_lines(last):
		sheet.add_child(ScreenKit.label(line, LINE_SIZE, ScreenKit.RED))
	var back: Button = ScreenKit.button(tr("round.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	sheet.add_child(back)
	ScreenKit.reveal(sheet)
	back.grab_focus()


## What Overfulfillment did to the round's bank, for a result that carries a stake.
static func stake_line(last: Dictionary) -> String:
	if bool(last["stake"]):
		var amount: String = Strings.score(float(last["banked"]))
		return TranslationServer.translate("round.stake.won").format({"amount": amount})
	return TranslationServer.translate("round.stake.lost")


## Overtime's and Grain Tax's lines, for a result they cut.
static func debuff_lines(last: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if last.has("voided"):
		lines.append(TranslationServer.translate("round.voided"))
	if last.has("taxed"):
		var amount: String = Strings.score(float(last["taxed"]))
		lines.append(TranslationServer.translate("round.taxed").format({"amount": amount}))
	return lines


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
				result["won"] = (played.seat == landlord) == (landlord == Seats.PLAYER)
		elif event.type == RunEvent.Type.ROUND_SCORED and event.seat == Seats.PLAYER:
			result["score"] = event.amount
		elif event.type == RunEvent.Type.SHARE_PAID and event.seat == Seats.PLAYER:
			result["share"] = event.value
		elif event.type == RunEvent.Type.STAKE_SETTLED and event.seat == Seats.PLAYER:
			result["stake"] = event.value == 1
			result["banked"] = event.amount
		elif event.type == RunEvent.Type.GRAIN_TAXED and event.seat == Seats.PLAYER:
			result["taxed"] = event.amount
		elif event.type == RunEvent.Type.BANK_VOIDED and event.seat == Seats.PLAYER:
			result["voided"] = event.amount
		if result.has("won"):
			finished = result
	return finished

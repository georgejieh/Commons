class_name RoundSummaryScreen
extends Control
## The last finished round: which side won, your score, your Commons share and
## where the Quota stands. Opened from the table's menu; Back returns to the table.

## The stake's and the bank's lines, at Standard.
const LINE_SIZE: int = 24

var _app: App


## Builds the report of the last finished round; call once when the screen is opened.
func open(app: App) -> void:
	_app = app
	var controller: RunController = app.controller
	var state: RunView = controller.run
	var sheet: VBoxContainer = SheetPad.over_board(self, SheetPad.BOARD_WIDTH)
	var last: RoundResult = RoundResult.last(controller.set_events())
	var title_key: String = "round.none"
	if last != null:
		title_key = "round.won" if last.won else "round.lost"
	else:
		last = RoundResult.new()
	var eyebrow: String = tr("round.eyebrow").format({"round": maxi(1, state.round_index())})
	sheet.add_child(ScreenKit.header(eyebrow, tr(title_key)))
	var tiles: Array[Control] = [
		StatTile.rolling(tr("round.score"), last.score),
		StatTile.rolling(tr("round.share"), float(last.share)),
		StatTile.figure(tr("round.progress"), state, RunCorrections.PROGRESS, state.set_progress()),
	]
	sheet.add_child(ScreenKit.row(tiles, 20))
	# Overfulfillment's stake is part of the result: the bank multiplied, or voided.
	if last.staked:
		sheet.add_child(ScreenKit.label(stake_line(last), LINE_SIZE, ScreenKit.RED))
	# What debuffs took from the bank is part of the result too (ADR 0023).
	for line: String in debuff_lines(last):
		sheet.add_child(ScreenKit.label(line, LINE_SIZE, ScreenKit.RED))
	var back: Button = ScreenKit.button(tr("round.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	sheet.add_child(back)
	ScreenKit.reveal(sheet)
	back.grab_focus()


## Cancel (Escape, or B on a pad) goes back, as Back does.
func _unhandled_input(event: InputEvent) -> void:
	if ScreenKit.take_cancel(self, event):
		_app.back()


## What Overfulfillment did to the round's bank, for a result that carries a stake.
static func stake_line(last: RoundResult) -> String:
	if last.stake_won:
		var amount: String = Strings.score(last.banked)
		return TranslationServer.translate("round.stake.won").format({"amount": amount})
	return TranslationServer.translate("round.stake.lost")


## Overtime's and Grain Tax's lines, for a result they cut.
static func debuff_lines(last: RoundResult) -> PackedStringArray:
	var lines: PackedStringArray = []
	if last.voided:
		lines.append(TranslationServer.translate("round.voided"))
	if last.taxed:
		var amount: String = Strings.score(last.tax)
		lines.append(TranslationServer.translate("round.taxed").format({"amount": amount}))
	return lines

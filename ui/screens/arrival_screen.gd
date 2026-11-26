class_name ArrivalScreen
extends Control
## The Arrival page (ADR 0026), offered on a first launch after the content note: one
## line from the brigade office, then Sit in, which starts the arrival, or Skip, which
## asks once and goes to the title. Sit in has the focus.

## The arrival's words, at Standard.
const TEXT_SIZE: int = 28

var _sit_in: Button
var _skip: Button
var _confirm: SkipConfirm = SkipConfirm.new()


func open(app: DemoApp) -> void:
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.title_night)
	sheet.add_child(ScreenKit.header("", tr("tutorial.arrival.title")))
	var line: Label = ScreenKit.label(tr("tutorial.arrival.text"), TEXT_SIZE)
	line.custom_minimum_size = Vector2(900, 0)
	sheet.add_child(line)
	_sit_in = ScreenKit.button(tr("tutorial.arrival.sit_in"), CommonsTheme.PRIMARY)
	_sit_in.pressed.connect(func() -> void: app.arrival.start())
	_skip = ScreenKit.button(tr("tutorial.skip"), CommonsTheme.GHOST)
	_skip.pressed.connect(_confirm.ask)
	sheet.add_child(ScreenKit.row([_sit_in, _skip]))
	add_child(_confirm)
	_confirm.skipped.connect(func() -> void: app.arrival.skip())
	ScreenKit.reveal(sheet)
	_sit_in.grab_focus()


func sit_in_button() -> Button:
	return _sit_in


func skip_button() -> Button:
	return _skip


func confirm() -> SkipConfirm:
	return _confirm


## The page's line, for tests.
func text() -> String:
	return tr("tutorial.arrival.text")

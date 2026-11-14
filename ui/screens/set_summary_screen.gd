class_name SetSummaryScreen
extends Control
## After a Set: the Quota report. The verdict is stamped on, the Quota bar fills to what
## was scored and is sealed met or short, then what it paid or cost is counted in, and
## the way on opens: to the store or, after the run's last Set, to the Year's summary.
## The button works from the start, so the report can be skipped.

const BAR: Vector2 = Vector2(960, 54)
const SEAL_WIDTH: float = 150.0
## Seconds before the bar starts, the bar takes to fill, and between the lines after.
const START: float = 0.2
const FILL: float = 0.7
const BEAT: float = 0.18

var _bar: QuotaBar = QuotaBar.new()
var _met: bool = false
## What is counted in once the bar is sealed: tiles, then the line saying what it means.
var _after: Array[Control] = []


func open(app: DemoApp) -> void:
	var controller: RunController = app.controller
	var state: RunState = controller.state_copy()
	_met = state.set_progress >= controller.target()
	var sheet: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.notice_wall)
	var verdict: Control = ScreenKit.header(
		tr("set.type.%d" % state.set_type), tr("summary.met" if _met else "summary.missed")
	)
	sheet.add_child(verdict)
	_bar.setup(BAR, SEAL_WIDTH, 30)
	_bar.set_target(controller.target())
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sheet.add_child(_bar)
	var paid: int = controller.quota_reward() if _met else 0
	var cost: int = _famine_rise(controller)
	var tiles: Array[Control] = [
		_stat(tr("summary.coupons_label"), state.coupons - paid, state.coupons, ScreenKit.COUPON),
		_stat(tr("summary.famine_label"), state.famine - cost, state.famine, ScreenKit.RED),
	]
	var row: Control = ScreenKit.row(tiles, 20)
	sheet.add_child(row)
	var line: Label = _consequence(controller, state.famine)
	sheet.add_child(line)
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
	_after = [row, line]
	UiMotion.stamp(verdict)
	next.grab_focus()
	_bar.filled.connect(_on_filled)
	if UiMotion.reduced():
		_bar.fill_to(state.set_progress, 0.0)
		return
	for piece: Control in _after:
		piece.modulate.a = 0.0
	_bar.fill_to(state.set_progress, FILL, START)


## How much Famine the Quota's end added: every Famine change logged after the last
## round was scored. Read from the log, because a rise can be cut off at the top.
func _famine_rise(controller: RunController) -> int:
	var rise: int = 0
	for event: RunEvent in controller.set_events():
		if event.type == RunEvent.Type.ROUND_SCORED:
			rise = 0
		elif event.type == RunEvent.Type.METER_CHANGED and event.text == TableHud.FAMINE:
			rise += event.value
	return rise


## The bar and its count, for tests.
func bar() -> QuotaBar:
	return _bar


## The bar is full: a short Quota is sealed in black, then the results are counted in.
func _on_filled() -> void:
	if not _met:
		_bar.seal_short()
	if UiMotion.reduced():
		return
	var tween: Tween = create_tween()
	for piece: Control in _after:
		tween.tween_interval(BEAT)
		tween.tween_property(piece, "modulate:a", 1.0, BEAT)
		tween.parallel().tween_callback(UiMotion.pulse.bind(piece))


## A tile whose number rolls from what it was before the Quota ended to what it is now,
## in ink when it changed.
func _stat(caption: String, from: int, to: int, ink: Color) -> Control:
	var tile: VBoxContainer = ScreenKit.card(Vector2(240, 0))
	tile.add_child(ScreenKit.eyebrow(caption))
	var number: Label = ScreenKit.styled(str(from), CommonsTheme.TITLE)
	if from != to:
		number.add_theme_color_override("font_color", ink)
	tile.add_child(number)
	var roll: Callable = func(shown: float) -> String: return str(roundi(shown))
	if UiMotion.reduced() or from == to:
		number.text = str(to)
	else:
		var tween: Tween = number.create_tween()
		tween.tween_interval(START + FILL + BEAT * 2.0)
		tween.tween_callback(UiMotion.count.bind(number, float(from), float(to), roll))
	return ScreenKit.card_panel(tile)


## What the result means: the coupons it paid, or the Famine it cost and what Famine does.
func _consequence(controller: RunController, famine: int) -> Label:
	var text: String
	if _met:
		text = Strings.count("summary.paid", controller.quota_reward())
	else:
		text = tr("summary.cost").format({"rise": _famine_rise(controller), "famine": famine})
	var line: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	line.add_theme_font_size_override("font_size", 26)
	line.add_theme_color_override("font_color", ScreenKit.INK if _met else ScreenKit.RED)
	return line

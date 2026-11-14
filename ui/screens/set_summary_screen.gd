class_name SetSummaryScreen
extends Control
## After a Set: the Quota report. The verdict is stamped on, the Quota bar fills to what
## was scored and is sealed met or short, and a Quota beaten by a step or more is sealed
## overfulfilled in gold beside it. Then what it paid or cost is counted in, with the
## norm it raised, and the way on opens: to the store or, after the run's last Set, to
## the Year's summary. The button works from the start, so the report can be skipped.

const BAR: Vector2 = Vector2(960, 54)
const SEAL_WIDTH: float = 150.0
## The overfulfilled seal is wider for its longer word, and sits left of the met seal.
const OVER_WIDTH: float = 176.0
const OVER_GAP: float = 12.0
## Seconds before the bar starts, the bar takes to fill, and between the lines after.
const START: float = 0.2
const FILL: float = 0.7
const BEAT: float = 0.18

var _bar: QuotaBar = QuotaBar.new()
var _met: bool = false
var _over: InkSeal = InkSeal.new()
var _steps: int = 0
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
	_steps = controller.over_steps() if _met else 0
	_over.prepare(tr("summary.over"), ScreenKit.GOLD, OVER_WIDTH)
	var met_left: float = BAR.x - SEAL_WIDTH * 0.6
	_over.position = Vector2(met_left - OVER_WIDTH - OVER_GAP, (BAR.y - OVER_WIDTH) / 2.0)
	_bar.add_child(_over)
	var paid: int = controller.quota_reward() + controller.over_bonus() if _met else 0
	var cost: int = _famine_rise(controller)
	var tiles: Array[Control] = [
		_stat(tr("summary.coupons_label"), state.coupons - paid, state.coupons, ScreenKit.COUPON),
		_stat(tr("summary.famine_label"), state.famine - cost, state.famine, ScreenKit.RED),
	]
	var row: Control = ScreenKit.row(tiles, 20)
	sheet.add_child(row)
	var line: Label = _consequence(controller, state.famine)
	sheet.add_child(line)
	_after = [row, line]
	if _steps > 0:
		var norm: Label = _line(
			tr("summary.norm_raised").format({"percent": controller.norm_added_percent()}),
			ScreenKit.RED
		)
		sheet.add_child(norm)
		_after.append(norm)
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


## The word on the overfulfilled seal, or "" while there is none. For tests.
func over_seal_word() -> String:
	return _over.word() if _over.visible else ""


## The bar is full: a short Quota is sealed in black, an overfulfilled one in gold beside
## its met seal, then the results are counted in.
func _on_filled() -> void:
	if not _met:
		_bar.seal_short()
	if UiMotion.reduced():
		if _steps > 0:
			_over.press()
		return
	var tween: Tween = create_tween()
	if _steps > 0:
		tween.tween_interval(BEAT)
		tween.tween_callback(_over.press)
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


## What the result means: the coupons it paid, bonus and all, or the Famine it cost and
## what Famine does.
func _consequence(controller: RunController, famine: int) -> Label:
	if _met:
		var paid: int = controller.quota_reward() + controller.over_bonus()
		return _line(Strings.count("summary.paid", paid), ScreenKit.INK)
	var text: String = tr("summary.cost").format(
		{"rise": _famine_rise(controller), "famine": famine}
	)
	return _line(text, ScreenKit.RED)


func _line(text: String, ink: Color) -> Label:
	var line: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	line.add_theme_font_size_override("font_size", 26)
	line.add_theme_color_override("font_color", ink)
	return line

class_name SetSummaryScreen
extends Control
## After a Set: the Quota report. The verdict is stamped on, the Quota bar fills to what
## was scored and is sealed met or short, and a Quota beaten by a step or more is sealed
## overfulfilled in gold beside it. Then what it paid or cost is counted in, with the
## norm it raised, and the way on opens: to the store or, after the run's last Set, to
## the Year's summary. The button works from the start, so the report can be skipped.
## Coupons The Bookkeeper paid at the Quota's end are counted in with the reward, and
## the paid line says so (ADR 0021). A family that starved, or was put out of the
## landlord's seat, gets one plain line in ink at the foot, and nothing more (ADR 0025).
## A Quota that ended without the player in the landlord's seat says what that cost, or,
## on the last free one, that the next will cost (ADR 0031). Every figure shows as
## ShownFigures says (ADR 0022): a dark Famine is "None reported" with no rise named, a
## dark norm hides the target and the norm's rise, and at the stage past the last the
## Quota reads as met and every figure as a success.

## The bar leaves room at its right end inside the sheet's padding for the met seal,
## which overhangs it, so the seal stays on the paper.
const BAR: Vector2 = Vector2(900, 54)
## The bar's count, at Standard.
const BAR_TEXT_SIZE: int = 30
## The width, in pixels, of the met seal.
const SEAL_WIDTH: float = 150.0
## The overfulfilled seal is wider for its longer word.
const OVER_WIDTH: float = 176.0
## How far, in pixels, the overfulfilled seal sits clear left of the met seal, whose band reaches
## past its ring when tilted.
const OVER_GAP: float = 30.0
## A deeper gold than the bar's, so the second seal reads on paper.
const OVER_INK: Color = Color("a8791a")
## Seconds before the bar starts to fill.
const START: float = 0.2
## Seconds the bar takes to fill.
const FILL: float = 0.7
## Seconds between the lines that follow the bar, and each one's fade in.
const BEAT: float = 0.18
## The font size of a family's fate, at Standard.
const FATE_SIZE: int = 22
## The font size of the report's other lines, at Standard.
const LINE_SIZE: int = 26

## What is counted in once the bar is sealed: tiles, then the line saying what it means.
var after: Array[Control] = []
var _bar: QuotaBar = QuotaBar.new()
var _met: bool = false
var _over: InkSeal = InkSeal.new()
var _steps: int = 0
## Coupons The Bookkeeper paid at this Quota's end.
var _kept: int = 0
## The families the Quota's end took, faded in last with no pulse: a quiet beat.
var _quiet: Array[Control] = []
var _fate_texts: PackedStringArray = []
var _seat_texts: PackedStringArray = []
var _next: Button
## The run as the page opened on it, for how its figures show.
var _state: RunView = null
## What the Quota's close paid and cost.
var _closing: QuotaClosing
var _norm_text: String = ""


## Builds the report and starts the bar filling; call once when the screen is opened.
func open(app: App) -> void:
	var controller: RunController = app.controller
	var state: RunView = controller.run
	_met = state.set_progress() >= controller.figures.target()
	_state = state
	_closing = QuotaClosing.new(controller.set_events())
	var sheet: VBoxContainer = SheetPad.over_board(self, SheetPad.BOARD_WIDTH)
	var verdict: Control = ScreenKit.header(
		tr("set.type.%d" % state.set_type()),
		tr("summary.met" if ShownFigures.reads_met(_met) else "summary.missed")
	)
	sheet.add_child(verdict)
	sheet.add_child(_seal_room(_quota_bar(controller, state)))
	for piece: Control in _results(controller, state):
		sheet.add_child(piece)
		after.append(piece)
	for fate: Label in _fates(controller):
		sheet.add_child(fate)
		_quiet.append(fate)
	_next = _way_on(app)
	sheet.add_child(_next)
	UiMotion.stamp(verdict)
	_next.grab_focus()
	_bar.filled.connect(_on_filled)
	if UiMotion.reduced():
		_bar.fill_to(state.set_progress(), 0.0)
		return
	for piece: Control in after + _quiet:
		piece.modulate.a = 0.0
	_bar.fill_to(state.set_progress(), FILL, START)


## The Quota bar at the run's target, with the overfulfilled seal ready beside its met
## seal.
func _quota_bar(controller: RunController, state: RunView) -> QuotaBar:
	_bar.setup(BAR, SEAL_WIDTH, BAR_TEXT_SIZE)
	_bar.show_as(QuotaBar.mode_for(state))
	_bar.set_target(controller.figures.target())
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_steps = controller.figures.over_steps() if _met else 0
	_over.prepare(tr("summary.over"), OVER_INK, OVER_WIDTH)
	var met_left: float = BAR.x - SEAL_WIDTH * 0.6
	_over.position = Vector2(met_left - OVER_WIDTH - OVER_GAP, (BAR.y - OVER_WIDTH) / 2.0)
	_bar.add_child(_over)
	return _bar


## What is counted in once the bar is sealed: the coupons and Famine tiles, the line
## saying what they mean, what The Bookkeeper kept, the norm and what the empty landlord's
## seat cost.
func _results(controller: RunController, state: RunView) -> Array[Control]:
	_kept = _closing.bookkeeper_paid
	var paid: int = (
		_kept + (controller.figures.quota_reward() + controller.figures.over_bonus() if _met else 0)
	)
	var cost: int = _closing.famine_rise
	var tiles: Array[Control] = [
		_figure(
			tr("summary.coupons_label"),
			RunCorrections.COUPONS,
			state.coupons() - paid,
			state.coupons()
		),
		_figure(
			tr("summary.famine_label"), RunCorrections.FAMINE, state.famine() - cost, state.famine()
		),
	]
	# The tiles share the sheet's width, so no half of the row stands empty.
	for tile: Control in tiles:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pieces: Array[Control] = [
		ScreenKit.row(tiles, 20), _consequence(controller, state.famine())
	]
	if _kept > 0 and not _met:
		var kept: String = Strings.count("summary.cadre_paid", _kept)
		pieces.append(_line(kept.format({"cadre": _bookkeeper(controller)}), ScreenKit.INK))
	var norm: Label = _norm_line(controller, state)
	if norm != null:
		pieces.append(norm)
	for seat_line: Label in _seat_lines(controller, state.seatless_sets()):
		pieces.append(seat_line)
	return pieces


## The way on: to the store, or after the run's last Set to the Year's summary.
func _way_on(app: App) -> Button:
	var controller: RunController = app.controller
	var way_on: String = "summary.to_year" if controller.is_last_set() else "summary.to_store"
	# In the arrival Wang says "Press Continue" (ADR 0026).
	if app.arrival.is_running():
		way_on = "summary.continue"
	var next: Button = ScreenKit.button(tr(way_on), CommonsTheme.PRIMARY)
	next.pressed.connect(
		func() -> void:
			if not app.arrival.attempt("continue"):
				return
			controller.finish_set()
			app.show_screen(app.screen_for(controller.awaiting()), true)
	)
	return next


## The seals overhang the bar above and below; the bar stands in a band as tall as the
## wider seal, so the figures under it never cover a seal.
func _seal_room(quota_bar: QuotaBar) -> MarginContainer:
	var room: MarginContainer = MarginContainer.new()
	var overhang: int = ceili((maxf(OVER_WIDTH, SEAL_WIDTH) - BAR.y) / 2.0)
	room.add_theme_constant_override("margin_bottom", overhang)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(quota_bar)
	return room


## How far the Quota was beaten, and what that did to the norm: a step or more
## raises it, and the line says by how much and to what; beaten by less, it says the norm
## stayed. Nothing while the norm is dark or the Quota was missed or only just met.
func _norm_line(controller: RunController, state: RunView) -> Label:
	if not _met or not ShownFigures.is_true(state, RunCorrections.NORM):
		return null
	var target: float = controller.figures.target()
	if not target > 0.0:
		return null
	var over: int = floori((state.set_progress() - target) * 100.0 / target)
	if over <= 0:
		return null
	var values: Dictionary[String, Variant] = {
		"over": over,
		"added": controller.figures.norm_added_percent(),
		"total": controller.figures.norm_percent(),
	}
	var key: String = "summary.norm_raised" if _steps > 0 else "summary.norm_kept"
	_norm_text = tr(key).format(values)
	var line: Label = _line(_norm_text, ScreenKit.RED if _steps > 0 else ScreenKit.INK)
	# Two sentences: it wraps inside the paper instead of pushing the sheet wider.
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


## The line about the norm, or "" with none, for tests.
func norm_text() -> String:
	return _norm_text


## The name of the Cadre that pays as a Quota closes.
func _bookkeeper(controller: RunController) -> String:
	return controller.texts.modifier_name(QuotaClosing.BOOKKEEPER)


## One line per family this Quota's end took from the village: starved, or deposed.
func _fates(controller: RunController) -> Array[Label]:
	var lines: Array[Label] = []
	for event: RunEvent in controller.set_events():
		var key: String = ""
		if event.type == RunEvent.Type.STARVED:
			key = "summary.starved"
		elif event.type == RunEvent.Type.DEPOSED:
			key = "summary.deposed"
		if key.is_empty():
			continue
		var surname: String = tr(controller.seats.family_name_key(event.text))
		var text: String = tr(key).format({"name": surname})
		var line: Label = ScreenKit.label(text, FATE_SIZE, ScreenKit.INK)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.append(line)
		_fate_texts.append(text)
	return lines


## What leaving the landlord's seat to others came to at this Quota's end: the Famine it
## added, or the warning on the last free Quota. The loop logs both; nothing is worked out
## here. The run's last Quota has no next one to warn of.
func _seat_lines(controller: RunController, count: int) -> Array[Label]:
	var lines: Array[Label] = []
	for event: RunEvent in controller.set_events():
		if event.type != RunEvent.Type.STOOD_BY:
			continue
		if event.value == 0 and controller.is_last_set():
			continue
		var key: String = "summary.stood_by" if event.value > 0 else "summary.stood_by_last"
		if event.value > 0 and not ShownFigures.is_true(_state, RunCorrections.FAMINE):
			key = "summary.stood_by.unreported"
		var text: String = tr(key).format({"count": count, "rise": roundi(event.amount)})
		lines.append(_line(text, ScreenKit.RED if event.value > 0 else ScreenKit.INK))
		_seat_texts.append(text)
	return lines


## The lines saying what leaving the landlord's seat cost, for tests.
func seat_lines() -> PackedStringArray:
	return _seat_texts


## The lines naming who the village lost this Quota, for tests.
func fate_lines() -> PackedStringArray:
	return _fate_texts


## What the arrival points at here: the way on.
func tutorial_target(key: String) -> Control:
	return _next if key == "continue" else null


## What the arrival's slip keeps clear of here: every result counted in, so the slip by
## the way on never stands over a line the Quota's report gives.
func tutorial_avoid() -> Array[Rect2]:
	var avoid: Array[Rect2] = []
	for piece: Control in after + _quiet:
		if piece.is_visible_in_tree():
			avoid.append(piece.get_global_rect())
	return avoid


## The overfulfilled seal, for tests.
func over_seal() -> InkSeal:
	return _over


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
	for piece: Control in after:
		tween.tween_interval(BEAT)
		tween.tween_property(piece, "modulate:a", 1.0, BEAT)
		tween.parallel().tween_callback(UiMotion.pulse.bind(piece))
	for piece: Control in _quiet:
		tween.tween_interval(BEAT)
		tween.tween_property(piece, "modulate:a", 1.0, BEAT * 2.0)


## A figure's tile: its number rolling as _stat() rolls it, or its words while it is not
## shown as it is.
func _figure(caption: String, figure: String, from: int, to: int) -> Control:
	var words: String = ShownFigures.tile_text(_state, figure)
	var ink: Color = ScreenKit.COUPON if figure == RunCorrections.COUPONS else ScreenKit.RED
	if words.is_empty():
		return _stat(caption, from, to, ink)
	var tile: VBoxContainer = ScreenKit.card(Vector2(240, 0))
	tile.add_child(ScreenKit.eyebrow(caption))
	tile.add_child(ScreenKit.styled(words, CommonsTheme.TITLE))
	return ScreenKit.card_panel(tile)


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
	if not _met and ShownFigures.all_success():
		return _line(tr("summary.fulfilled"), ScreenKit.INK)
	if _met:
		var paid: int = controller.figures.quota_reward() + controller.figures.over_bonus() + _kept
		if _kept > 0:
			var words: Dictionary[String, Variant] = {
				"count": paid, "kept": _kept, "cadre": _bookkeeper(controller)
			}
			return _line(tr("summary.paid_with").format(words), ScreenKit.INK)
		return _line(Strings.count("summary.paid", paid), ScreenKit.INK)
	var text: String = tr("summary.cost").format({"rise": _closing.famine_rise, "famine": famine})
	if not ShownFigures.is_true(_state, RunCorrections.FAMINE):
		text = tr("summary.famine").format({"value": ShownFigures.none_reported()})
	return _line(text, ScreenKit.RED)


func _line(text: String, ink: Color) -> Label:
	var line: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	line.add_theme_font_size_override("font_size", TextSize.px(LINE_SIZE))
	line.add_theme_color_override("font_color", ink)
	return line

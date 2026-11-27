class_name SmallLedger
extends PanelContainer
## The household's own books at the stage past the last (ADR 0022): a small typed slip
## that keeps the true figures while every other figure on screen reads as a success, so
## the game stays playable. It shows them as the stages before it do: a figure that went
## dark is "None reported" here too. It is a ration-slip stub as the village has it
## (PaperTicket), yellowed and thumbed at stage 0 and worse at every stage, and it is
## hidden at every other stage. The table keeps one in its Work Points panel and both
## shops beside the coupons.

## The font size of the slip's figures, at Standard.
const LINE_SIZE: int = 16
## The padding inside the slip, in pixels: across (x) and down (y).
const MARGIN: Vector2i = Vector2i(16, 8)
## The grime salt of the table's slip.
const TABLE_SALT: int = 3
## The grime salt of the shops' slips, which differs from the table's so they are not alike.
const SHOP_SALT: int = 5
## Figures on the slip, wherever it is.
const LINES: int = 4

## The number that varies this slip's grime from another's; the show call that last ran sets it.
var salt: int = 0
var _grid: GridContainer = GridContainer.new()


func _init(pairs_per_row: int = 1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margins: StyleBoxEmpty = StyleBoxEmpty.new()
	margins.content_margin_left = MARGIN.x
	margins.content_margin_right = MARGIN.x
	margins.content_margin_top = MARGIN.y
	margins.content_margin_bottom = MARGIN.y + 6
	add_theme_stylebox_override("panel", margins)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_typed(tr("ledger.books.title").to_upper(), true))
	_grid.columns = pairs_per_row * 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Made once: a slip that is written again at every event instances nothing.
	for _line: int in LINES:
		_grid.add_child(_typed("", true))
		_grid.add_child(_typed("", false))
	column.add_child(_grid)
	add_child(column)
	visible = false


## The table's figures: the Quota, both meters and the coupons.
func show_table(state: RunView, target: float) -> void:
	salt = TABLE_SALT
	if not _shows():
		return
	var quota: String = ShownFigures.ledger_quota(state, state.set_progress(), target)
	_write(0, tr("keyword.quota.name"), quota)
	_write(1, tr("meter.famine"), _meter(state, RunCorrections.FAMINE, state.famine()))
	var denunciation: String = _meter(state, RunCorrections.DENUNCIATION, state.denunciation())
	_write(2, tr("meter.denunciation"), denunciation)
	_write(3, tr("summary.coupons_label"), str(state.coupons()))


## A shop's figures: the coupons and the three meters.
func show_shop(state: RunView) -> void:
	salt = SHOP_SALT
	if not _shows():
		return
	_write(0, tr("summary.coupons_label"), str(state.coupons()))
	var resentment: String = _meter(state, RunCorrections.RESENTMENT, state.resentment())
	_write(1, tr("keyword.resentment.name"), resentment)
	_write(2, tr("meter.famine"), _meter(state, RunCorrections.FAMINE, state.famine()))
	var denunciation: String = _meter(state, RunCorrections.DENUNCIATION, state.denunciation())
	_write(3, tr("meter.denunciation"), denunciation)


## Every line on the slip as "name value", for tests; empty while it is hidden.
func texts() -> PackedStringArray:
	var lines: PackedStringArray = []
	if not visible:
		return lines
	for index: int in range(0, _grid.get_child_count(), 2):
		var label_cell: Label = _grid.get_child(index)
		var value: Label = _grid.get_child(index + 1)
		lines.append("%s %s" % [label_cell.text, value.text])
	return lines


## Shown only at the stage past the last.
func _shows() -> bool:
	visible = ShownFigures.all_success()
	if visible:
		queue_redraw()
	return visible


## Writes one figure's name and value on its line of the slip.
func _write(line: int, label_text: String, value: String) -> void:
	(_grid.get_child(line * 2) as Label).text = label_text
	(_grid.get_child(line * 2 + 1) as Label).text = value


func _meter(state: RunView, figure: String, value: int) -> String:
	return ShownFigures.ledger_meter(state, figure, value)


func _typed(text: String, bold: bool) -> Label:
	var line: Label = Label.new()
	line.text = text
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_override(
		"font", ScreenKit.TYPEWRITER_BOLD if bold else ScreenKit.TYPEWRITER
	)
	line.add_theme_font_size_override("font_size", TextSize.px(LINE_SIZE))
	line.add_theme_color_override("font_color", BowlGrime.faded(ScreenKit.INK, BowlGrime.wear()))
	return line


func _draw() -> void:
	PaperTicket.draw(self, Rect2(Vector2.ZERO, size), BowlGrime.wear(), salt, ScreenKit.FAINT_INK)

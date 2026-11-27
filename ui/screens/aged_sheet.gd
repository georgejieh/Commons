class_name AgedSheet
extends PanelContainer
## A sheet of the village's card stock that keyboard, gamepad and mouse can reach
## (ADR 0025): an item to read, a choice to pick, or, for something still locked, a blank
## sheet with only the line saying when it opens. It is foxed and thumbed from corruption
## stage 0 and worse at every stage (art/STYLE.md, "Nothing is clean"). A choosable sheet
## sends chosen on a click or an accept press; the chosen one is ringed in red ink, the
## focused one in faded gold.

## Sent when a choosable sheet is clicked or an accept key is pressed on it.
signal chosen

## The seed its foxing and stains are drawn from, with the sheet's index added, so a sheet always
## looks the same.
const SEED: int = 8317
## The fewest foxing specks a sheet carries, at corruption stage 0, and the most, at the worst
## stage.
const SPECKS: Vector2i = Vector2i(6, 34)
## The card-stock margin inside the sheet, in pixels.
const PADDING: int = 20
## The size of the line on a locked sheet that says when it opens, at Standard text.
const LOCKED_SIZE: int = 18

## True when a click or accept press picks it.
var choosable: bool = false
## True while it is the one picked.
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Which sheet this is, so each keeps its own stains.
var which: int = 0
var _column: VBoxContainer = VBoxContainer.new()


func _init(min_width: float = 0.0, sheet_index: int = 0) -> void:
	which = sheet_index
	custom_minimum_size = Vector2(min_width, 0)
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	_column.add_theme_constant_override("separation", 8)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## A blank sheet for a locked item: its line and nothing else, in text, tooltip or the
## name a screen reader hears.
static func blank(line: String, min_size: Vector2, sheet_index: int = 0) -> AgedSheet:
	var sheet: AgedSheet = AgedSheet.new(min_size.x, sheet_index)
	sheet.custom_minimum_size = min_size
	sheet.accessibility_name = line
	if not line.is_empty():
		var label: Label = ScreenKit.label(line, LOCKED_SIZE, ScreenKit.PAPER_EDGE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sheet.column().add_child(label)
	return sheet


## The column its words go in.
func column() -> VBoxContainer:
	return _column


func _gui_input(event: InputEvent) -> void:
	if not choosable:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		chosen.emit()


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 131 * which
	var rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-10.0)
	var speck: Color = Color(BowlGrime.TEA, 0.2 + 0.35 * worn)
	for _spot: int in roundi(lerpf(SPECKS.x, SPECKS.y, worn)):
		var at: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		draw_circle(at, rng.randf_range(0.6, 1.6), speck)
	var thumb: Vector2 = rect.position + Vector2(rng.randf_range(0.2, 0.8), 0.85) * rect.size
	draw_circle(
		thumb, minf(rect.size.x, rect.size.y) * 0.14, Color(BowlGrime.TEA, 0.05 + 0.1 * worn)
	)
	if worn > 0.5:
		var ring: Vector2 = rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var tea: Color = Color(BowlGrime.TEA, 0.18 * worn)
		draw_arc(ring, rect.size.x * 0.2, 0.0, TAU, 24, tea, 1.5 + worn, true)
	if selected:
		var ink: Color = BowlGrime.faded(ScreenKit.PICKED, worn)
		draw_rect(Rect2(Vector2.ZERO, size).grow(-5.0), ink, false, 4.0)
		draw_rect(Rect2(Vector2.ZERO, size).grow(-11.0), Color(ink, 0.6), false, 1.5)
	if has_focus():
		var gold: Color = Color(BowlGrime.aged(ScreenKit.FOCUS_RING, worn * 0.5), 0.9)
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.5), gold, false, 3.0)

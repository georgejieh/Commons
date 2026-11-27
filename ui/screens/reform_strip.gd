class_name ReformStrip
extends PanelContainer
## The Reforms in force (ADR 0021), on a paper strip across the notes column that both
## shops show: each enacted Reform a pinned decree slip with its name, in the order
## enacted, wrapping onto a second line when they will not fit one, so the player can
## always see what they hold. Hovering a slip or giving it focus asks the
## screen's DetailSlip for its rules. A newly pinned one swells as it lands.

## A slip is hovered or has focus; the screen's slip should show that Reform's rules.
signal described(tag: Control, reform_id: String)
## A slip is no longer hovered or focused; the screen's slip should be put away.
signal left(tag: Control)

## The height, in pixels, of a slip and of the heading's row.
const TAG_HEIGHT: float = 38.0
## The room, in pixels, added to a Reform's name to make its slip's width.
const TAG_PADDING: float = 22.0
## The font size of a Reform's name on its slip, at Standard.
const NAME_SIZE: int = 16
## The font size of the strip's heading, at Standard.
const HEAD_SIZE: int = 16
## The room, in pixels, between slips, across and down.
const GAP: int = 8
## Clear of the paper's printed border.
const PADDING: int = 20

## The strip's heading.
var heading: Label = ScreenKit.eyebrow("")
## Says so when no Reform is in force.
var none_line: Label = ScreenKit.label("", NAME_SIZE)
var _row: HFlowContainer = HFlowContainer.new()
var _column: VBoxContainer = VBoxContainer.new()
var _tags: Array[Control] = []
var _ids: Array[String] = []
var _names: Array[String] = []


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = _column
	column.add_theme_constant_override("separation", 4)
	_row.add_theme_constant_override("h_separation", GAP)
	_row.add_theme_constant_override("v_separation", GAP)
	_row.custom_minimum_size = Vector2(0, TAG_HEIGHT)
	column.add_child(_row)
	# The head leads the row of slips, so the strip keeps to one line while they fit.
	var head: Label = heading
	head.text = tr("reform.strip").to_upper()
	head.add_theme_font_size_override("font_size", TextSize.px(HEAD_SIZE))
	for label: Label in [head, none_line]:
		label.custom_minimum_size = Vector2(0, TAG_HEIGHT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_row.add_child(label)
	none_line.text = tr("reform.strip.none")
	none_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	none_line.add_theme_color_override("font_color", ScreenKit.INK)
	add_child(column)


## "None yet" stands on the head's baseline. Both are centred in the row, and their faces
## set the baseline at different depths, so the higher one is pushed down to meet the other.
func _ready() -> void:
	var gap: float = baseline(heading) - baseline(none_line)
	var higher: Label = none_line if gap > 0.0 else heading
	var push: StyleBoxEmpty = StyleBoxEmpty.new()
	# A top margin moves centred text down by half of it.
	push.content_margin_top = absf(gap) * 2.0
	higher.add_theme_stylebox_override("normal", push)


## Where a label's baseline sits in the row, centred in TAG_HEIGHT with no margin.
static func baseline(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var px: int = label.get_theme_font_size("font_size")
	var ascent: float = font.get_ascent(px)
	return (TAG_HEIGHT - ascent - font.get_descent(px)) / 2.0 + ascent


## Prints a shop's note on the strip's sheet, above the slips: one sheet, one border.
func add_note(note: Control) -> void:
	_column.add_child(note)
	_column.move_child(note, 0)


## Shows the Reforms the run holds, one slip each.
func show_reforms(controller: RunController) -> void:
	_ids = controller.items.held_reforms()
	_names.clear()
	for reform_id: String in _ids:
		_names.append(controller.texts.reform_name(reform_id))
	while _tags.size() < _ids.size():
		var shown: Control = Control.new()
		shown.focus_mode = Control.FOCUS_ALL
		shown.mouse_filter = Control.MOUSE_FILTER_STOP
		shown.draw.connect(_draw_tag.bind(shown))
		var index: int = _tags.size()
		shown.mouse_entered.connect(_describe.bind(index))
		shown.focus_entered.connect(_describe.bind(index))
		shown.mouse_exited.connect(func() -> void: left.emit(shown))
		shown.focus_exited.connect(func() -> void: left.emit(shown))
		shown.focus_entered.connect(shown.queue_redraw)
		shown.focus_exited.connect(shown.queue_redraw)
		_row.add_child(shown)
		_tags.append(shown)
	for index: int in _tags.size():
		var shown: Control = _tags[index]
		shown.visible = index < _ids.size()
		if shown.visible:
			shown.custom_minimum_size = Vector2(_width(_names[index]), TAG_HEIGHT)
			shown.queue_redraw()
	none_line.visible = _ids.is_empty()


## The slip for the Reform enacted index-th, for tests and the pinning.
func tag(index: int) -> Control:
	return _tags[index]


## How many Reforms the strip shows; for tests and the playtest.
func held_count() -> int:
	return _ids.size()


## Where the next Reform's slip will be pinned, its middle on screen.
func next_center() -> Vector2:
	var count: int = _ids.size()
	if count == 0 or count > _tags.size():
		return none_line.global_position + Vector2(TAG_PADDING, TAG_HEIGHT / 2.0)
	var last: Control = _tags[count - 1]
	return last.global_position + Vector2(last.size.x + GAP + TAG_PADDING, TAG_HEIGHT / 2.0)


## Swells a pinned slip, as when its Reform lands on the strip.
func pulse(index: int) -> void:
	if index >= 0 and index < _tags.size():
		_tags[index].pivot_offset = _tags[index].size / 2.0
		UiMotion.pulse(_tags[index])


func _describe(index: int) -> void:
	if index < _ids.size():
		described.emit(_tags[index], _ids[index])


func _width(text: String) -> float:
	var font: Font = get_theme_default_font()
	var name_px: int = TextSize.px(NAME_SIZE)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x + TAG_PADDING


func _draw_tag(drawn: Control) -> void:
	var index: int = _tags.find(drawn)
	if index < 0 or index >= _names.size():
		return
	var worn: float = BowlGrime.wear()
	DecreePaper.tag(drawn, Rect2(Vector2.ZERO, drawn.size), worn, _ids[index].hash() & 0xFF)
	var font: Font = get_theme_default_font()
	var ink: Color = BowlGrime.faded(ScreenKit.INK, worn)
	var name_px: int = TextSize.px(NAME_SIZE)
	var at: Vector2 = Vector2(TAG_PADDING * 0.62, drawn.size.y * 0.5 + name_px * 0.42)
	drawn.draw_string(font, at, _names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, name_px, ink)
	if drawn.has_focus():
		var gold: Color = CampaignPaper.ink(ScreenKit.HINT, worn * 0.5)
		drawn.draw_rect(Rect2(Vector2.ZERO, drawn.size).grow(2.0), gold, false, 2.0)

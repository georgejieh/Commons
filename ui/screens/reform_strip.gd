class_name ReformStrip
extends PanelContainer
## The Reforms in force (ADR 0021), on a short paper strip that both shops show: each
## enacted Reform a small pinned decree slip with its name, in the order enacted, so the
## player can always see what they hold. Hovering a slip or giving it focus asks the
## screen's DetailSlip for its rules. A newly pinned one swells as it lands.

## A slip is hovered or focused, or no longer is.
signal described(tag: Control, reform_id: String)
signal left(tag: Control)

const TAG_HEIGHT: float = 34.0
const TAG_PADDING: float = 22.0
const NAME_SIZE: int = 13
const GAP: int = 6
const INK: Color = Color("2b2119")

var _row: HBoxContainer = HBoxContainer.new()
var _none: Label = ScreenKit.label("", NAME_SIZE)
var _tags: Array[Control] = []
var _ids: Array[String] = []
var _names: Array[String] = []


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(10))
	size_flags_horizontal = Control.SIZE_SHRINK_END
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var head: Label = ScreenKit.eyebrow("")
	head.text = TranslationServer.translate("reform.strip").to_upper()
	head.add_theme_font_size_override("font_size", 14)
	column.add_child(head)
	_row.add_theme_constant_override("separation", GAP)
	_row.custom_minimum_size = Vector2(0, TAG_HEIGHT)
	column.add_child(_row)
	_none.text = TranslationServer.translate("reform.strip.none")
	_none.autowrap_mode = TextServer.AUTOWRAP_OFF
	_none.add_theme_color_override("font_color", ScreenKit.STYLE.ink_soft)
	_row.add_child(_none)
	add_child(column)


## Shows the Reforms the run holds, one slip each.
func show_reforms(controller: RunController) -> void:
	_ids = controller.held_reforms()
	_names.clear()
	for reform_id: String in _ids:
		_names.append(controller.reform_name(reform_id))
	while _tags.size() < _ids.size():
		var tag: Control = Control.new()
		tag.focus_mode = Control.FOCUS_ALL
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		tag.draw.connect(_draw_tag.bind(tag))
		var index: int = _tags.size()
		tag.mouse_entered.connect(_describe.bind(index))
		tag.focus_entered.connect(_describe.bind(index))
		tag.mouse_exited.connect(func() -> void: left.emit(tag))
		tag.focus_exited.connect(func() -> void: left.emit(tag))
		tag.focus_entered.connect(tag.queue_redraw)
		tag.focus_exited.connect(tag.queue_redraw)
		_row.add_child(tag)
		_tags.append(tag)
	for index: int in _tags.size():
		var tag: Control = _tags[index]
		tag.visible = index < _ids.size()
		if tag.visible:
			tag.custom_minimum_size = Vector2(_width(_names[index]), TAG_HEIGHT)
			tag.queue_redraw()
	_none.visible = _ids.is_empty()


## The slip for the Reform enacted index-th, for tests and the pinning.
func tag(index: int) -> Control:
	return _tags[index]


func held_count() -> int:
	return _ids.size()


## Where the next Reform's slip will be pinned, its middle on screen.
func next_center() -> Vector2:
	var count: int = _ids.size()
	if count == 0 or count > _tags.size():
		return _row.global_position + Vector2(TAG_PADDING, TAG_HEIGHT / 2.0)
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
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x + TAG_PADDING


func _draw_tag(tag: Control) -> void:
	var index: int = _tags.find(tag)
	if index < 0 or index >= _names.size():
		return
	var worn: float = BowlGrime.wear()
	DecreePaper.tag(tag, Rect2(Vector2.ZERO, tag.size), worn, _ids[index].hash() & 0xFF)
	var font: Font = get_theme_default_font()
	var ink: Color = CampaignPaper.ink(INK, worn * 0.5)
	var baseline: Vector2 = Vector2(TAG_PADDING * 0.62, tag.size.y * 0.5 + NAME_SIZE * 0.42)
	tag.draw_string(font, baseline, _names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, ink)
	if tag.has_focus():
		var gold: Color = CampaignPaper.ink(CampaignLeaflet.GOLD, worn * 0.5)
		tag.draw_rect(Rect2(Vector2.ZERO, tag.size).grow(2.0), gold, false, 2.0)

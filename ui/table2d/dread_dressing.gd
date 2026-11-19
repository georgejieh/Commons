class_name DreadDressing
extends Control
## The dread layers' set dressing (P3B.12), drawn over the room and under the cards,
## seats and controls: empty chairs at the room's edge, a poster about your household,
## black bars over the brigade notice, a spotlight on your seat and gilt trim for a
## landlord. Shapes are placeholders until the art pass (P3C). Each piece fades with its
## weight; none covers anything the player reads.

const LAMP_SHADER: Shader = preload("res://shaders/lamp_light.gdshader")
const WOOD: Color = Color("2a1a10")
const PAPER: Color = Color("d9c8a4")
const INK: Color = Color("1e1a16")
const RED: Color = Color("9e1b16")
const GILT: Color = Color("c9a227")
## Where the pieces sit, in the table's 1920x1080 frame: wall space clear of the seats,
## play lanes, hand, buttons and ledger.
const NOTICE_AT: Rect2 = Rect2(150, 622, 280, 124)
const POSTER_AT: Rect2 = Rect2(1190, 520, 200, 200)
const CHAIR_SPOTS: Array[Vector2] = [Vector2(36, 560), Vector2(1440, 590)]
const EXTRA_CHAIR_SPOT: Vector2 = Vector2(740, 330)
const REDACTION_LINES: int = 3
## A redaction bar's height as a share of a line of the notice's text, its left inset
## and how much further in, and shorter, each line down starts.
const BAR_SHARE: float = 22.0 / 28.0
const BAR_INSET: float = 14.0
const BAR_STEP: Vector2 = Vector2(9, 30)

var spotlight_material: ShaderMaterial = ShaderMaterial.new()

var _pieces: Dictionary[String, Control] = {}
var _flash_until: Dictionary[String, int] = {}
var _notice: PanelContainer = PanelContainer.new()
var _notice_words: Label = Label.new()
var _bars: Control = Control.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_spotlight()
	_add_notice()
	_add_chairs("empty_chairs", CHAIR_SPOTS)
	_add_chairs("extra_chair", [EXTRA_CHAIR_SPOT] as Array[Vector2])
	_add_poster()
	_add_gilt()


## Where the brigade notice hangs on screen, for what must keep clear of it.
func notice_rect() -> Rect2:
	return _notice.get_global_rect() if _notice.is_inside_tree() else Rect2()


## Fades a piece to weight; at 0 it is hidden.
func show_piece(piece: String, weight: float) -> void:
	if not _pieces.has(piece):
		return
	var flashing: bool = Time.get_ticks_msec() < _flash_until.get(piece, 0)
	var control: Control = _pieces[piece]
	control.modulate.a = 1.0 if flashing else weight
	control.visible = flashing or weight > 0.01


## Shows a piece in full for a moment, as a flicker.
## Pieces no layer drives, such as the extra chair, hide again on their own.
func flash_piece(piece: String, seconds: float) -> void:
	if not _pieces.has(piece):
		return
	_flash_until[piece] = Time.get_ticks_msec() + int(seconds * 1000.0)
	show_piece(piece, 0.0)
	var control: Control = _pieces[piece]
	var tween: Tween = control.create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(_end_flash.bind(piece))


func _end_flash(piece: String) -> void:
	_flash_until.erase(piece)
	var control: Control = _pieces[piece]
	control.visible = control.visible and control.modulate.a < 1.0 and control.modulate.a > 0.01


func is_shown(piece: String) -> bool:
	return _pieces.has(piece) and _pieces[piece].visible


func _add_spotlight() -> void:
	var spot: ColorRect = ColorRect.new()
	spotlight_material.shader = LAMP_SHADER
	spotlight_material.set_shader_parameter("pool_center", Vector2(0.4, 0.84))
	spotlight_material.set_shader_parameter("pool_radius", Vector2(0.48, 0.3))
	spotlight_material.set_shader_parameter("darkness", 0.9)
	spotlight_material.set_shader_parameter("breathe", 0.0)
	spot.material = spotlight_material
	_place("spotlight", spot, Rect2(Vector2.ZERO, Vector2(1920, 1080)))
	spot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The brigade notice is always on the wall; only its redaction bars come and go. At a
## larger text size its paper grows upward (ADR 0034), its bottom and left edges kept, so
## it never reaches the status line under it, and the bars follow the lines of its text.
func _add_notice() -> void:
	var notice: PanelContainer = _notice
	notice.add_theme_stylebox_override("panel", _box(PAPER, INK, 2))
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.position = NOTICE_AT.position
	notice.custom_minimum_size = NOTICE_AT.size
	var words: Label = _notice_words
	words.text = tr("dread.notice")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(NOTICE_AT.size.x - 24, 0)
	words.add_theme_color_override("font_color", INK)
	words.add_theme_font_size_override("font_size", TextSize.px(18))
	notice.add_child(words)
	add_child(notice)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line: int in REDACTION_LINES:
		var bar: ColorRect = ColorRect.new()
		bar.color = INK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.add_child(bar)
	_place("redaction", _bars, NOTICE_AT)
	notice.resized.connect(_fit_notice)
	# Its rect, not its size: the bars follow where the notice sets its words.
	words.item_rect_changed.connect(_fit_notice)
	_fit_notice()


## Stands the notice as tall as its words need, up from its bottom edge, and lays a bar
## over each of the first lines of its text, centred on the line.
func _fit_notice() -> void:
	var tall: float = maxf(NOTICE_AT.size.y, _notice.get_combined_minimum_size().y)
	var top: Vector2 = Vector2(NOTICE_AT.position.x, NOTICE_AT.end.y - tall)
	if _notice.position != top or _notice.size.y != tall:
		_notice.position = top
		_notice.size = Vector2(NOTICE_AT.size.x, tall)
	_bars.position = top
	_bars.custom_minimum_size = _notice.size
	_bars.size = _notice.size
	var line_tall: float = _notice_words.get_line_height()
	var pitch: float = line_tall + _notice_words.get_theme_constant("line_spacing")
	var bar_tall: float = roundf(line_tall * BAR_SHARE)
	for line: int in _bars.get_child_count():
		var bar: ColorRect = _bars.get_child(line) as ColorRect
		var middle: float = _notice_words.position.y + line * pitch + line_tall / 2.0
		bar.position = Vector2(BAR_INSET + line * BAR_STEP.x, roundf(middle - bar_tall / 2.0))
		bar.size = Vector2(NOTICE_AT.size.x - 40.0 - line * BAR_STEP.y, bar_tall)


## The rects the redaction bars cover, on screen, for tests.
func redaction_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for bar: Node in _bars.get_children():
		rects.append((bar as Control).get_global_rect())
	return rects


## The notice's words, for tests.
func notice_words() -> Label:
	return _notice_words


func _add_chairs(piece: String, spots: Array[Vector2]) -> void:
	var group: Control = Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spot: Vector2 in spots:
		for part: Rect2 in [
			Rect2(0, 0, 14, 120), Rect2(0, 60, 80, 14), Rect2(66, 60, 14, 70), Rect2(0, 70, 14, 60)
		]:
			var piece_part: ColorRect = ColorRect.new()
			piece_part.color = WOOD
			piece_part.position = spot + part.position
			piece_part.size = part.size
			piece_part.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_child(piece_part)
	_place(piece, group, Rect2(Vector2.ZERO, Vector2.ZERO))


func _add_poster() -> void:
	var poster: PanelContainer = PanelContainer.new()
	poster.add_theme_stylebox_override("panel", _box(PAPER, RED, 6))
	var words: Label = Label.new()
	words.text = tr("dread.poster")
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.add_theme_color_override("font_color", RED)
	words.add_theme_font_size_override("font_size", TextSize.px(24))
	words.custom_minimum_size = Vector2(POSTER_AT.size.x - 24, 0)
	poster.add_child(words)
	_place("poster", poster, POSTER_AT)


func _add_gilt() -> void:
	var trim: Panel = Panel.new()
	var style: StyleBoxFlat = _box(Color.TRANSPARENT, GILT, 10)
	style.draw_center = false
	trim.add_theme_stylebox_override("panel", style)
	_place("gilt", trim, Rect2(0, 72, 1920, 1008))
	trim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trim.offset_top = 72


func _place(piece: String, control: Control, at: Rect2) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	if at.size != Vector2.ZERO:
		control.position = at.position
		control.custom_minimum_size = at.size
		control.size = at.size
	control.visible = false
	_pieces[piece] = control


static func _box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

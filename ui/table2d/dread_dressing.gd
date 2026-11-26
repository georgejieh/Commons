class_name DreadDressing
extends Control
## The dread layers' set dressing, drawn over the room and under the cards, seats and
## controls: empty chairs at the room's edge, a notice about your household under the Cadre
## board, black bars over the brigade notice, a spotlight on your seat and gilt trim for a
## landlord, and the brigade's roster under the right seat, whose names fade as the roster
## effect grows. The chairs, bars, spotlight and trim are flat rectangles and boxes drawn
## in code. Each piece fades with its weight; none covers anything the player reads, and
## the rules slip may stand in front of the right chair (ADR 0034, rule 6).

const LAMP_SHADER: Shader = preload("res://shaders/lamp_light.gdshader")
const WOOD: Color = Color("2a1a10")
## Where the brigade notice sits at Standard, in the table's 1920x1080 frame, on wall
## space clear of the seats, play lanes, hand, buttons and ledger: worn paper like every
## sheet, its words inside the paper's printed border, its right edge clear of the trick's
## room.
const NOTICE_AT: Rect2 = Rect2(118, 606, 312, 140)
const NOTICE_PADDING: int = 22
## The household notice, wide and low, between the Cadre board's foot (y 268) and the
## trick's box (y 380), 6 px clear of each, so it never covers either; its words on one
## line.
const POSTER_AT: Rect2 = Rect2(492, 274, 596, 100)
const POSTER_SIZE: int = 24
const CHAIR_SPOTS: Array[Vector2] = [Vector2(36, 560), Vector2(1440, 590)]
## Between the trick's foot and the hand, right of the status line.
const EXTRA_CHAIR_SPOT: Vector2 = Vector2(1030, 690)
## The roster's left edge: the right seat's, under it.
const ROSTER_X: float = 1120.0
const REDACTION_LINES: int = 3
## The brigade notice changes with every deal: this many notices for each stretch of a
## run, and the last Year of the early and of the middle stretch.
const NOTICES: int = 4
const EARLY_UNTIL: int = 2
const MID_UNTIL: int = 5
## A redaction bar's height as a share of a line of the notice's text, how far it starts
## left of the words, and how much further in, and shorter, each line down starts.
const BAR_SHARE: float = 22.0 / 28.0
const BAR_INSET: float = 4.0
const BAR_STEP: Vector2 = Vector2(9, 30)

var spotlight_material: ShaderMaterial = ShaderMaterial.new()

var _pieces: Dictionary[String, Control] = {}
var _flash_until: Dictionary[String, int] = {}
var _notice: PanelContainer = PanelContainer.new()
var _notice_words: Label = Label.new()
var _bars: Control = Control.new()
var _roster: WallRoster = WallRoster.new()
## True while the notice is taken down for the Campaign tray (ADR 0034, rule 8).
var _notice_down: bool = false
var _notice_fade: Tween = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_spotlight()
	_add_notice()
	_add_chairs("empty_chairs", CHAIR_SPOTS)
	_add_chairs("extra_chair", [EXTRA_CHAIR_SPOT] as Array[Vector2])
	_add_poster()
	_add_gilt()
	_roster.visible = false
	add_child(_roster)


## Where the brigade notice hangs on screen, for what must keep clear of it; nothing
## while it is taken down.
func notice_rect() -> Rect2:
	if not _notice.is_inside_tree() or _notice_down:
		return Rect2()
	return _notice.get_global_rect()


## The key of the notice the brigade has posted: plain and welcome in a run's early
## Years, a notch wrong in the middle ones and further wrong in the last. turn counts on
## with each Set and round, so the wall is not the same from one deal to the next.
static func notice_key(year: int, turn: int) -> String:
	var stretch: String = "late"
	if year <= EARLY_UNTIL:
		stretch = "early"
	elif year <= MID_UNTIL:
		stretch = "mid"
	return "dread.notice.%s.%d" % [stretch, posmod(turn, NOTICES)]


## Posts a notice by its key; its redaction bars follow its words.
func post_notice(key: String) -> void:
	var text: String = tr(key)
	if _notice_words.text == text:
		return
	_notice_words.text = text
	# Stood again at once, so whoever lays the left column out next reads its true top.
	_notice_words.update_minimum_size()
	_notice.update_minimum_size()
	_fit_notice()


## The words on the notice now, for tests.
func notice_text() -> String:
	return _notice_words.text


## Where the notice's top stands when it is up, at the text size now.
func notice_top() -> float:
	return _notice.position.y


## Takes the notice down when the left column needs its wall, and puts it back when
## there is room again: it fades as the other pieces do, at once under reduced motion.
## Its redaction bars go with it.
func take_down_notice(down: bool) -> void:
	if down == _notice_down:
		return
	_notice_down = down
	UiMotion.end(_notice_fade)
	var weight: float = 0.0 if down else 1.0
	if down:
		_bars.visible = false
	else:
		_notice.visible = true
	if UiMotion.reduced():
		_notice.modulate.a = weight
		_notice.visible = not down
		return
	_notice_fade = _notice.create_tween()
	_notice_fade.tween_property(_notice, "modulate:a", weight, UiMotion.PRESETS.hover_time * 2.0)
	if down:
		_notice_fade.tween_callback(_notice.hide)


func is_notice_down() -> bool:
	return _notice_down


## Hangs the roster with its foot at foot when it fits below top, or takes it down: it is
## the first thing the right column gives up.
func hang_roster(top: float, foot: float) -> void:
	var extent: Vector2 = _roster.get_combined_minimum_size()
	_roster.size = extent
	_roster.position = Vector2(ROSTER_X, foot - extent.y)
	_roster.visible = foot - extent.y >= top


func roster() -> WallRoster:
	return _roster


## Where the roster hangs on screen, or nothing while it is down.
func roster_rect() -> Rect2:
	return _roster.get_global_rect() if _roster.is_visible_in_tree() else Rect2()


## Fades a piece to weight; at 0 it is hidden.
func show_piece(piece: String, weight: float) -> void:
	if not _pieces.has(piece):
		return
	var flashing: bool = Time.get_ticks_msec() < _flash_until.get(piece, 0)
	var control: Control = _pieces[piece]
	control.modulate.a = 1.0 if flashing else weight
	control.visible = (flashing or weight > 0.01) and not (piece == "redaction" and _notice_down)


## Shows a piece in full for a moment, as a flicker. Pieces no layer drives, such as the
## extra chair, hide again on their own.
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
	notice.add_theme_stylebox_override("panel", ScreenKit.paper_style(NOTICE_PADDING))
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.position = NOTICE_AT.position
	notice.custom_minimum_size = NOTICE_AT.size
	var words: Label = _notice_words
	words.text = tr(DreadDressing.notice_key(1, 0))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(NOTICE_AT.size.x - 2 * NOTICE_PADDING, 0)
	words.add_theme_color_override("font_color", ScreenKit.INK)
	words.add_theme_font_size_override("font_size", TextSize.px(18))
	notice.add_child(words)
	add_child(notice)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line: int in REDACTION_LINES:
		var bar: ColorRect = ColorRect.new()
		bar.color = ScreenKit.INK
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
		var left: float = _notice_words.position.x - BAR_INSET + line * BAR_STEP.x
		bar.position = Vector2(left, roundf(middle - bar_tall / 2.0))
		var wide: float = _notice_words.size.x + BAR_INSET - line * (BAR_STEP.x + BAR_STEP.y)
		bar.size = Vector2(wide, bar_tall)


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
	poster.add_theme_stylebox_override("panel", _box(ScreenKit.OLD_PAPER, ScreenKit.SEAL, 6))
	var words: Label = Label.new()
	words.text = tr("dread.poster")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.add_theme_color_override("font_color", ScreenKit.SEAL)
	poster.add_child(words)
	_place("poster", poster, POSTER_AT)
	# One line, print in a fixed box: it fits down, never under its Standard size.
	var font: Font = words.get_theme_font("font")
	var room: float = POSTER_AT.size.x - poster.get_theme_stylebox("panel").get_minimum_size().x
	var fits: Callable = func(font_size: int) -> bool:
		return font.get_string_size(words.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room
	words.add_theme_font_size_override("font_size", TextSize.fit(POSTER_SIZE, POSTER_SIZE, fits))


func _add_gilt() -> void:
	var trim: Panel = Panel.new()
	var style: StyleBoxFlat = _box(Color.TRANSPARENT, ScreenKit.HINT, 10)
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

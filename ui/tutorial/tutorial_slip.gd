class_name TutorialSlip
extends PanelContainer
## Wang's slip in the arrival (ADR 0026): his face beside one or two sentences in dark
## ink on the village's aged paper. It stands beside what it points at, never over it nor
## over the player's hand, and pulses once when an action is refused; under reduced
## motion its border goes red for a moment instead, with a cross of two strokes in its
## top right corner, so the refusal does not rest on colour alone (ADR 0035).

## The slip's usual width in pixels.
const WIDTH: float = 540.0
## The size of Wang's face, in pixels.
const FACE: Vector2 = Vector2(96, 112)
## The type size of the slip's line, at Standard.
const TEXT_SIZE: int = 24
## The gap the slip keeps from the thing it stands beside.
const GAP: float = 28.0
## The gap the slip keeps from the screen's edge.
const MARGIN: float = 16.0
## The paper's padding round the face and the line, in pixels.
const PADDING: int = 20
## The gap between Wang's face and his line.
const FACE_GAP: int = 14
## The width of the red border under reduced motion.
const ALARM_WIDTH: float = 5.0
## Seconds the red border holds under reduced motion.
const ALARM_SECONDS: float = 0.6
## The side of the cross's box inside the slip's top right corner.
const CROSS: float = 22.0
## How far in from the slip's top right corner the cross sits.
const CROSS_INSET: float = 12.0
## The width of the cross's two strokes.
const CROSS_WIDTH: float = 4.0

var _face: TextureRect = TextureRect.new()
var _text: Label = Label.new()
var _alarm: bool = false


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", FACE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.custom_minimum_size = FACE
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_face)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_width(WIDTH)
	_text.add_theme_font_size_override("font_size", TextSize.px(TEXT_SIZE))
	_text.add_theme_color_override("font_color", ScreenKit.INK)
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)
	add_child(row)
	visible = false


## Sets the picture of Wang's face.
func set_face(face: Texture2D) -> void:
	_face.texture = face


## Makes the slip width wide, or WIDTH, its line wrapping to fit; its height follows.
func set_width(wide: float) -> void:
	_text.custom_minimum_size = Vector2(wide - FACE.x - FACE_GAP - PADDING * 2.0, 0)
	reset_size()


## Shows the line, sized to it, at the text size chosen now: the slip outlives screens.
func say(spoken: String) -> void:
	_text.text = spoken
	_text.add_theme_font_size_override("font_size", TextSize.px(TEXT_SIZE))
	visible = not spoken.is_empty()
	reset_size()


## The line the slip says now; for tests.
func line() -> String:
	return _text.text


## The font size the line is drawn at now; for tests.
func text_size() -> int:
	return _text.get_theme_font_size("font_size")


## Stands beside target, keeping clear of it and of every rect in avoid, on screen. The
## first place that fits wins: right, left, then above and below, each centred on the
## target and then lined up with either of its edges, then above and below slid just
## past each rect it must keep clear of, nearest the target first.
func place(target: Rect2, avoid: Array[Rect2], screen: Vector2) -> void:
	reset_size()
	global_position = TutorialSlip.spot(size, target, avoid, screen)


## Where a slip of this size stands beside target, clear of it and of avoid.
static func spot(extent: Vector2, target: Rect2, avoid: Array[Rect2], screen: Vector2) -> Vector2:
	var middle: Vector2 = target.get_center()
	var above: float = target.position.y - GAP - extent.y
	var below: float = target.end.y + GAP
	var tries: Array[Vector2] = [
		Vector2(target.end.x + GAP, middle.y - extent.y / 2.0),
		Vector2(target.position.x - GAP - extent.x, middle.y - extent.y / 2.0),
	]
	for y: float in [above, below]:
		for x: float in [middle.x - extent.x / 2.0, target.position.x, target.end.x - extent.x]:
			tries.append(Vector2(x, y))
	var slid: Array[Vector2] = []
	for y: float in [above, below]:
		for other: Rect2 in avoid:
			slid.append(Vector2(other.end.x + GAP, y))
			slid.append(Vector2(other.position.x - GAP - extent.x, y))
	# Nearest the target first, so the slip stays by what it points at.
	var near: Callable = func(a: Vector2, b: Vector2) -> bool:
		return (a + extent / 2.0).distance_to(middle) < (b + extent / 2.0).distance_to(middle)
	slid.sort_custom(near)
	tries.append_array(slid)
	var blocked: Array[Rect2] = avoid.duplicate()
	if target.has_area():
		blocked.append(target)
	for at: Vector2 in tries:
		var kept: Vector2 = _kept_on(at, extent, screen)
		var rect: Rect2 = Rect2(kept, extent)
		if not blocked.any(func(other: Rect2) -> bool: return other.intersects(rect)):
			return kept
	return _kept_on(tries[2], extent, screen)


static func _kept_on(at: Vector2, extent: Vector2, screen: Vector2) -> Vector2:
	var high: Vector2 = (screen - extent - Vector2.ONE * MARGIN).max(Vector2.ONE * MARGIN)
	return at.clamp(Vector2.ONE * MARGIN, high)


## Once per refused action: a pulse, or a red border under reduced motion.
func refuse() -> void:
	if not UiMotion.reduced():
		UiMotion.pulse(self)
		return
	_alarm = true
	queue_redraw()
	var tween: Tween = create_tween()
	tween.tween_interval(ALARM_SECONDS)
	tween.tween_callback(_calm)


func _calm() -> void:
	_alarm = false
	queue_redraw()


## Where the cross is drawn while the slip refuses, in the slip's own pixels.
func cross_rect() -> Rect2:
	return Rect2(Vector2(size.x - CROSS_INSET - CROSS, CROSS_INSET), Vector2.ONE * CROSS)


## True while the cross shows: only under reduced motion, for as long as the border.
func shows_cross() -> bool:
	return _alarm


func _draw() -> void:
	if not _alarm:
		return
	var alarm: Color = CommonsTheme.STYLE.vermilion
	draw_rect(Rect2(Vector2.ZERO, size), alarm, false, ALARM_WIDTH)
	# Two quick strokes of red pencil, not quite straight and not quite meeting.
	var box: Rect2 = cross_rect()
	var ink: Color = BowlGrime.faded(alarm, BowlGrime.wear())
	var bend: Vector2 = Vector2(1.5, -1.0)
	draw_polyline(
		PackedVector2Array([box.position, box.get_center() + bend, box.end]), ink, CROSS_WIDTH, true
	)
	var rise: PackedVector2Array = [
		Vector2(box.end.x + 1.0, box.position.y + 1.0),
		box.get_center() - bend,
		Vector2(box.position.x - 1.0, box.end.y),
	]
	draw_polyline(rise, ink, CROSS_WIDTH, true)

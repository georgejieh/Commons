class_name TutorialSlip
extends PanelContainer
## Wang's slip in the arrival (ADR 0026): his face beside one or two sentences in dark
## ink on the village's aged paper. It stands beside what it points at, never over it nor
## over the player's hand, and pulses once when an action is refused; under reduced
## motion its border goes red for a moment instead.

const WIDTH: float = 540.0
const FACE: Vector2 = Vector2(96, 112)
const TEXT_SIZE: int = 24
const GAP: float = 28.0
const MARGIN: float = 16.0
const PADDING: int = 16
const ALARM: Color = Color("b02a17")
const ALARM_WIDTH: float = 5.0
## Seconds the red border holds under reduced motion.
const ALARM_SECONDS: float = 0.6

var _face: TextureRect = TextureRect.new()
var _text: Label = Label.new()
var _alarm: bool = false


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.custom_minimum_size = FACE
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_face)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - FACE.x - 14.0 - PADDING * 2.0, 0)
	_text.add_theme_font_size_override("font_size", TEXT_SIZE)
	_text.add_theme_color_override("font_color", ScreenKit.INK)
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_text)
	add_child(row)
	visible = false


func set_face(face: Texture2D) -> void:
	_face.texture = face


## Shows the line, sized to it.
func say(line: String) -> void:
	_text.text = line
	visible = not line.is_empty()
	reset_size()


func line() -> String:
	return _text.text


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


func is_alarmed() -> bool:
	return _alarm


func _calm() -> void:
	_alarm = false
	queue_redraw()


func _draw() -> void:
	if _alarm:
		draw_rect(Rect2(Vector2.ZERO, size), ALARM, false, ALARM_WIDTH)

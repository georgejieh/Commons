class_name ScrollFade
extends Control
## A band of paper that fades in over a scroll's cut edge while more lies past that edge,
## so a sheet that scrolls shows that it does, and a row the edge cuts reads as "more",
## not as broken. It lies over the scroll and takes no input, and each band goes
## once the scroll reaches its end. It stands outside the scroll's layout (top level) and
## follows the scroll's place on screen each frame.

## How tall a band is, and how far it hides the paper's own colour at the very edge.
const BAND: float = 64.0
const DEPTH: float = 0.94
## The scroll counts as at an end within this many pixels of it.
const SLACK: float = 1.0

var _scroll: ScrollContainer
var _paper: Color
## The rect and the bands last drawn, so it redraws only when one changes.
var _drawn: Rect2 = Rect2()
var _bands: Vector2i = Vector2i(-1, -1)


## Lays a fade over scroll, in the paper's colour.
static func over(scroll: ScrollContainer, paper: Color = ScreenKit.STYLE.paper) -> ScrollFade:
	var fade: ScrollFade = ScrollFade.new()
	fade._scroll = scroll
	fade._paper = paper
	fade.name = "ScrollFade"
	fade.top_level = true
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.focus_mode = Control.FOCUS_NONE
	scroll.add_child(fade)
	return fade


## True while more of the content lies below what the scroll shows.
func more_below() -> bool:
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	return bar.max_value - bar.page - _scroll.scroll_vertical > SLACK


## True while more lies above it.
func more_above() -> bool:
	return _scroll.scroll_vertical > SLACK


func _process(_delta: float) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	var rect: Rect2 = _scroll.get_global_rect()
	var bands: Vector2i = Vector2i(int(more_above()), int(more_below()))
	if rect == _drawn and bands == _bands:
		return
	_drawn = rect
	_bands = bands
	global_position = rect.position
	size = rect.size
	queue_redraw()


func _draw() -> void:
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	# The band stops short of the bar, so the bar stays plain to see.
	var wide: float = size.x - (bar.size.x if bar.visible else 0.0)
	var tall: float = minf(BAND, size.y / 3.0)
	if _bands.x == 1:
		_band(Vector2(0.0, 0.0), wide, tall, true)
	if _bands.y == 1:
		_band(Vector2(0.0, size.y - tall), wide, tall, false)


## One band, its solid side at the edge.
func _band(at: Vector2, wide: float, tall: float, solid_top: bool) -> void:
	var clear: Color = Color(_paper, 0.0)
	var solid: Color = Color(_paper, DEPTH)
	var top: Color = solid if solid_top else clear
	var foot: Color = clear if solid_top else solid
	var points: PackedVector2Array = [
		at, at + Vector2(wide, 0.0), at + Vector2(wide, tall), at + Vector2(0.0, tall)
	]
	draw_polygon(points, [top, top, foot, foot])

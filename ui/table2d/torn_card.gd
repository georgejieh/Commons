class_name TornCard
extends Control
## Plot Seized at the table (ADR 0023): the destroyed plot card is held up beside the
## cut-in's words, torn in two down a ragged line, and its halves fall away from them. Two clipped
## copies of the real face make the halves; the torn edge is old paper, worn with
## BowlGrime.wear(). Reduced motion and quiet replays show nothing: the card is gone.

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
const SCALE: float = 1.6
const SHOW_TIME: float = 0.5
const TEAR_TIME: float = 0.6
const TEETH: int = 9
const TOOTH: float = 7.0

var _halves: Array[Control] = []
var _faces: Array[CardView] = []
var _edges: Array[Control] = []
var _face_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: int in 2:
		var half: Control = Control.new()
		half.clip_contents = true
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face: CardView = CARD_SCENE.instantiate()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.add_child(face)
		var edge: Control = Control.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.draw.connect(_draw_edge.bind(edge, side))
		half.add_child(edge)
		add_child(half)
		_halves.append(half)
		_faces.append(face)
		_edges.append(edge)
	visible = false


## The card's size as it is held up, before it tears.
func shown_size() -> Vector2:
	return _faces[0].custom_minimum_size * SCALE


## The halves on screen, for tests.
func halves() -> Array[Control]:
	return _halves.duplicate()


## Tears card held up with its middle at middle, then lets the halves fall. Returns how long the
## beat lasts, 0 when nothing is shown.
func tear(card: CardInstance, middle: Vector2) -> float:
	if UiMotion.reduced():
		visible = false
		return 0.0
	_face_size = _faces[0].custom_minimum_size
	var half_width: float = _face_size.x / 2.0
	for side: int in 2:
		var face: CardView = _faces[side]
		face.bind(card)
		face.pivot_offset = Vector2.ZERO
		face.position = Vector2(-half_width * side, 0.0)
		var half: Control = _halves[side]
		half.size = Vector2(half_width, _face_size.y)
		half.scale = Vector2.ONE * SCALE
		half.pivot_offset = Vector2(half_width * (1 - side), _face_size.y)
		half.rotation = 0.0
		half.modulate.a = 1.0
		var at: Vector2 = middle - _face_size * SCALE / 2.0 - global_position
		half.position = at + Vector2(half_width * SCALE * side, 0.0)
		_edges[side].size = half.size
		_edges[side].queue_redraw()
	visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(SHOW_TIME)
	for side: int in 2:
		var half: Control = _halves[side]
		# Both halves fall away from the words at the card's right, never across them.
		var away: float = -1.0 if side == 0 else -0.25
		tween.parallel().tween_property(half, "rotation", away * 0.5, TEAR_TIME).set_delay(
			SHOW_TIME
		)
		(
			tween
			. parallel()
			. tween_property(
				half, "position", half.position + Vector2(away * 120.0, 160.0), TEAR_TIME
			)
			. set_delay(SHOW_TIME)
		)
		tween.parallel().tween_property(half, "modulate:a", 0.0, TEAR_TIME).set_delay(SHOW_TIME)
	tween.tween_callback(hide)
	return SHOW_TIME + TEAR_TIME


## The ragged torn edge along each half's inner side, in worn paper.
func _draw_edge(edge: Control, side: int) -> void:
	var worn: float = BowlGrime.wear()
	var x: float = edge.size.x if side == 0 else 0.0
	var points: PackedVector2Array = [Vector2(x, 0.0)]
	for tooth: int in TEETH:
		var y: float = edge.size.y * (tooth + 0.5) / TEETH
		var bite: float = TOOTH if tooth % 2 == 0 else -TOOTH * 0.4
		points.append(Vector2(x - bite if side == 0 else x + bite, y))
	points.append(Vector2(x, edge.size.y))
	edge.draw_polyline(points, CampaignPaper.paper(worn), 5.0)
	edge.draw_polyline(points, Color(BowlGrime.TEA, 0.3 + 0.4 * worn), 1.5)

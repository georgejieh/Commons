class_name DiceBowl
extends Control
## The audit thrown as dice. A blue-and-white porcelain bowl, seen from above, drops into
## the middle of the table and the room dims; each claim's die is thrown in at once, they
## tumble, turning and changing faces, and settle on the faces rolled. Chinese dice: the
## one is a single large red pip, the four is four red pips, the rest are black. Each die
## is tinted for the seat it belongs to, with that person's name on a tag in the same
## tint. A die at or below the audit faces gets a red ring and a hop; the others fade a
## little. Then the bowl lifts away. Reduced motion shows the settled dice at once.

const SIDES: int = 6
const RADIUS: float = 220.0
const DIE: float = 70.0
## Seconds for the bowl to drop in, the dice to tumble, the settled dice to hold, the
## audited die to hop within that hold, and the bowl to lift away.
const DROP: float = 0.2
const ROLL: float = 0.9
const REST: float = 0.3
const HOP: float = 0.24
const LIFT: float = 0.2
## The bowl lands from this much larger, as if dropped from above.
const DROP_FROM: float = 1.45
const DIM: float = 0.3
## Face changes while a die tumbles, and the bounces it makes.
const FLIPS: int = 9
const BOUNCES: float = 3.5
const FADED: float = 0.55
const PORCELAIN: Color = Color("f5f7f9")
const GLAZE: Color = Color("dfe6f0")
const COBALT: Color = Color("1f3f8f")
const COBALT_SOFT: Color = Color("6f8cc4")
const PIP_RED: Color = Color("c0221a")
const PIP_BLACK: Color = Color("1e1a16")
const RING: Color = Color("b02a17")
const SHADOW: Color = Color(0.08, 0.06, 0.04, 0.32)
## Each seat's die and tag: the player ivory, seat 1 celadon, seat 2 pale indigo.
const TINTS: Dictionary[int, Color] = {
	0: Color("f3ead2"),
	1: Color("b9d6c2"),
	2: Color("b7c3e0"),
}
const TAG_SIZE: int = 22
## Pip places on a die, as fractions of its side from the middle.
const PIPS: Dictionary[int, Array] = {
	1: [Vector2(0, 0)],
	2: [Vector2(-0.26, -0.26), Vector2(0.26, 0.26)],
	3: [Vector2(-0.26, -0.26), Vector2(0, 0), Vector2(0.26, 0.26)],
	4: [Vector2(-0.24, -0.24), Vector2(0.24, -0.24), Vector2(-0.24, 0.24), Vector2(0.24, 0.24)],
	5:
	[
		Vector2(-0.26, -0.26),
		Vector2(0.26, -0.26),
		Vector2(0, 0),
		Vector2(-0.26, 0.26),
		Vector2(0.26, 0.26)
	],
	6:
	[
		Vector2(-0.22, -0.28),
		Vector2(-0.22, 0.0),
		Vector2(-0.22, 0.28),
		Vector2(0.22, -0.28),
		Vector2(0.22, 0.0),
		Vector2(0.22, 0.28)
	],
}

## Where the bowl's middle sits.
var center: Vector2 = Vector2.ZERO
## How far the bowl has dropped in, the dice have tumbled, the audited dice have hopped
## and the bowl has lifted away, each from 0 to 1. Tweened; everything is drawn from them.
var drop: float = 0.0
var tumble: float = 0.0
var hop: float = 0.0
var lift: float = 0.0
## How far the dice that were not audited have faded, from 0 to 1.
var fade: float = 0.0

var _seats: Array[int] = []
var _faces: Array[int] = []
var _names: Array[String] = []
var _audit_faces: int = 0
var _rolling: bool = false
var _tween: Tween = null
var _bodies: Dictionary[int, StyleBoxFlat] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide()


## A seat's tint, for anything else that shows whose die is whose.
static func tint_for(seat: int) -> Color:
	return TINTS.get(seat, TINTS[0])


## The seconds lift_away() will take.
static func lift_seconds() -> float:
	return 0.0 if UiMotion.reduced() else LIFT


## Drops the bowl in and throws one die per seat, each to settle on its face. names are
## the seats' names for the tags. Returns the seconds until the dice have settled and
## the audited ones have hopped.
func roll(seats: Array[int], faces: Array[int], audit_faces: int, names: Array[String]) -> float:
	dismiss()
	_seats = seats.duplicate()
	_faces = faces.duplicate()
	_names = names.duplicate()
	_audit_faces = audit_faces
	visible = true
	set_process(true)
	if UiMotion.reduced():
		drop = 1.0
		tumble = 1.0
		fade = 1.0
		queue_redraw()
		return UiMotion.seconds(ROLL + REST)
	_rolling = true
	_tween = create_tween()
	_tween.tween_property(self, "drop", 1.0, DROP).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_property(self, "tumble", 1.0, ROLL)
	_tween.tween_callback(_settle)
	var up: PropertyTweener = _tween.tween_property(self, "hop", 1.0, HOP * 0.5)
	up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fade", 1.0, HOP)
	var down: PropertyTweener = _tween.chain().tween_property(self, "hop", 0.0, HOP * 0.5)
	down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_interval(REST - HOP)
	return DROP + ROLL + REST


## Lifts the bowl away and hides it. Returns the seconds it takes.
func lift_away() -> float:
	if not visible:
		return 0.0
	_kill()
	_settle()
	if UiMotion.reduced():
		_hide()
		return 0.0
	_tween = create_tween()
	_tween.tween_property(self, "lift", 1.0, LIFT).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_callback(_hide)
	return LIFT


## Takes the bowl away at once.
func dismiss() -> void:
	_kill()
	_hide()


func is_showing() -> bool:
	return visible


## True from the throw until the dice settle.
func is_rolling() -> bool:
	return _rolling


## The faces the dice show now, in seat order as thrown, or none while the bowl is away.
func faces() -> Array[int]:
	var shown: Array[int] = []
	if not visible:
		return shown
	for index: int in _faces.size():
		shown.append(_shown_face(index))
	return shown


## The seats whose die landed at or below the audit faces.
func audited_seats() -> Array[int]:
	var seats: Array[int] = []
	for index: int in _faces.size():
		if _faces[index] <= _audit_faces:
			seats.append(_seats[index])
	return seats


func _process(_delta: float) -> void:
	queue_redraw()


func _settle() -> void:
	_rolling = false
	tumble = 1.0


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _hide() -> void:
	visible = false
	_rolling = false
	set_process(false)
	drop = 0.0
	tumble = 0.0
	hop = 0.0
	lift = 0.0
	fade = 0.0


func _draw() -> void:
	if not visible:
		return
	var alpha: float = clampf(drop * 2.0, 0.0, 1.0) * (1.0 - lift)
	var scale_now: float = lerpf(DROP_FROM, 1.0, drop) + lift * 0.12
	var middle: Vector2 = center + Vector2(0, -40.0 * lift)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, DIM * alpha))
	_draw_bowl(middle, RADIUS * scale_now, alpha)
	for index: int in _faces.size():
		_draw_tag(index, middle, scale_now, alpha)
	for index: int in _faces.size():
		_draw_die(index, middle, scale_now, alpha)


## A porcelain bowl from above: a cobalt band of pearls round the rim, a glazed wall
## shading inward, the foot ring inside and a flower at the bottom.
func _draw_bowl(at: Vector2, radius: float, alpha: float) -> void:
	draw_circle(at + Vector2(10, 16), radius * 1.02, Color(SHADOW, SHADOW.a * alpha))
	draw_circle(at, radius, Color(PORCELAIN, alpha))
	var band: float = radius * 0.07
	draw_arc(at, radius * 0.92, 0.0, TAU, 96, Color(COBALT, alpha), band, true)
	for index: int in 28:
		var angle: float = TAU * index / 28.0
		var pearl: Vector2 = at + Vector2.from_angle(angle) * radius * 0.92
		draw_circle(pearl, band * 0.26, Color(PORCELAIN, alpha))
	draw_arc(at, radius * 0.855, 0.0, TAU, 96, Color(COBALT, alpha), 2.0, true)
	for step: int in 6:
		var wall: float = radius * lerpf(0.84, 0.56, step / 5.0)
		draw_circle(at, wall, Color(GLAZE.lerp(PORCELAIN, step / 5.0), alpha))
	draw_arc(at, radius * 0.5, 0.0, TAU, 72, Color(COBALT, alpha), 3.0, true)
	draw_arc(at, radius * 0.46, 0.0, TAU, 72, Color(COBALT_SOFT, alpha), 1.5, true)
	for petal: int in 6:
		var spot: Vector2 = at + Vector2.from_angle(TAU * petal / 6.0) * radius * 0.11
		draw_circle(spot, radius * 0.065, Color(COBALT_SOFT, alpha * 0.8))
	draw_circle(at, radius * 0.05, Color(COBALT, alpha))
	var shine: Color = Color(1, 1, 1, 0.7 * alpha)
	draw_arc(at, radius * 0.97, PI * 1.08, PI * 1.55, 32, shine, 4.0, true)


## Where a die rests, and where it is thrown in from: the first from the lower left, the
## next from the upper right.
func _rest_at(index: int, middle: Vector2, scale_now: float) -> Vector2:
	var side: float = -1.0 if index % 2 == 0 else 1.0
	return middle + Vector2(side * 0.3, 0.04 * side) * RADIUS * scale_now


func _thrown_from(index: int, middle: Vector2, scale_now: float) -> Vector2:
	var side: float = -1.0 if index % 2 == 0 else 1.0
	return middle + Vector2(side * 1.05, -side * 0.8) * RADIUS * scale_now


## A die flies in high, bounces lower each time round the bowl, turns as it goes and
## comes to rest a little askew.
func _draw_die(index: int, middle: Vector2, scale_now: float, alpha: float) -> void:
	var rest: Vector2 = _rest_at(index, middle, scale_now)
	var from: Vector2 = _thrown_from(index, middle, scale_now)
	var t: float = clampf(tumble, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var path: Vector2 = from.lerp(rest, eased)
	var across: Vector2 = (rest - from).orthogonal().normalized()
	path += across * sin(t * PI * 2.0) * RADIUS * 0.22 * (1.0 - t)
	var height: float = absf(sin(t * PI * BOUNCES)) * pow(1.0 - t, 1.5) * 0.55
	var audited: bool = _faces[index] <= _audit_faces
	var lifted: float = hop if audited else 0.0
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var angle: float = side * ((1.0 - eased) * TAU * 2.0 + 0.12)
	var grow: float = (1.0 + height + lifted * 0.14) * scale_now
	var at: Vector2 = path + Vector2(0, -lifted * 14.0)
	var shade: float = alpha * (1.0 - height * 0.6)
	draw_circle(path + Vector2(6, 10) * (1.0 + height * 3.0), DIE * 0.5, Color(SHADOW, shade))
	var faded: float = 1.0 if audited else lerpf(1.0, FADED, fade)
	draw_set_transform(at, angle, Vector2.ONE * grow)
	var half: Vector2 = Vector2.ONE * DIE / 2.0
	var body: StyleBoxFlat = _body(_seats[index], alpha * faded)
	draw_style_box(body, Rect2(-half, half * 2.0))
	_draw_pips(_shown_face(index), alpha * faded)
	draw_set_transform(Vector2.ZERO, 0.0)
	if audited and tumble >= 1.0:
		var ring: Color = Color(RING, alpha)
		draw_arc(at, DIE * 0.86 * scale_now, 0.0, TAU, 48, ring, 5.0, true)


## The 1 and the 4 are red, as on Chinese dice; the 1 is one large pip.
func _draw_pips(face: int, alpha: float) -> void:
	var red: bool = face == 1 or face == 4
	var radius: float = DIE * (0.17 if face == 1 else 0.085)
	var ink: Color = Color(PIP_RED if red else PIP_BLACK, alpha)
	for place: Vector2 in PIPS.get(face, []):
		draw_circle(place * DIE, radius, ink)


## The seat's name on a tag of its tint, under where its die comes to rest.
func _draw_tag(index: int, middle: Vector2, scale_now: float, alpha: float) -> void:
	var font: Font = ScreenKit.DISPLAY_BOLD
	var text: String = _names[index] if index < _names.size() else ""
	if text.is_empty():
		return
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x
	var at: Vector2 = _rest_at(index, middle, scale_now) + Vector2(0, DIE * 0.95 * scale_now)
	var box: Rect2 = Rect2(at - Vector2(width / 2.0 + 12.0, 16.0), Vector2(width + 24.0, 32.0))
	var shown: float = alpha * clampf(tumble * 3.0, 0.0, 1.0)
	draw_rect(box, Color(tint_for(_seats[index]), shown))
	draw_rect(box, Color(PIP_BLACK, shown * 0.6), false, 2.0)
	var baseline: Vector2 = at + Vector2(-width / 2.0, TAG_SIZE * 0.36)
	var ink: Color = Color(PIP_BLACK, shown)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, ink)


## The face a die shows: changing fast as it is thrown and slower as it settles, then
## the face it rolled.
func _shown_face(index: int) -> int:
	var final: int = _faces[index]
	if tumble >= 1.0:
		return final
	var flip: int = floori(FLIPS * (1.0 - pow(1.0 - tumble, 2.0)))
	var turn: int = ((FLIPS - flip) * 5 + flip * flip + index * 2) % SIDES
	return (final - 1 + maxi(turn, 1)) % SIDES + 1


## A die's body in its seat's tint, at alpha. One box per seat, recoloured as it is drawn.
func _body(seat: int, alpha: float) -> StyleBoxFlat:
	if not _bodies.has(seat):
		var made: StyleBoxFlat = StyleBoxFlat.new()
		made.set_corner_radius_all(int(DIE * 0.2))
		made.set_border_width_all(3)
		made.anti_aliasing = true
		_bodies[seat] = made
	var body: StyleBoxFlat = _bodies[seat]
	body.bg_color = Color(tint_for(seat), alpha)
	body.border_color = Color(tint_for(seat).darkened(0.4), alpha)
	return body

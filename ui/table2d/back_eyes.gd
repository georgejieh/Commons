class_name BackEyes
extends Control
## The eye printed on a card back (P5.2c, the Plan's Denunciation rows): faint ink at
## first, a little darker as the board's dread grows, and from DreadEffects.eyes_follow_at
## its gaze turns, slowly, toward the pointer. It lies over a back as drawn, a seat's or a
## card in flight, takes no input and draws nothing on a clean profile, away from the
## table or at the lowest horror intensity. Under reduced motion it looks straight ahead.
## Worn like every printed thing (BowlGrime): the lids are uneven from the first stage.

const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
const INK: Color = Color("1e1a16")
const PAPER: Color = Color("efe3c8")
## The eye's width as a share of the back's, its height as a share of its width, and its
## middle as a share of the back's size.
const WIDTH_SHARE: float = 0.62
const HEIGHT_SHARE: float = 0.42
const MIDDLE: Vector2 = Vector2(0.5, 0.46)
## Points along each lid, and how far a lid's ink strays from a clean curve, as a share
## of the eye's height, at no wear and at the most.
const LID_POINTS: int = 12
const LID_STRAY: Vector2 = Vector2(0.04, 0.12)
## The iris's radius and the pupil's, as shares of the eye's height; how far the iris may
## turn, as a share of the room between it and the corners.
const IRIS: float = 0.42
const PUPIL: float = 0.5
const TURN: float = 0.7
## How far from the eye the pointer must be for the gaze to turn all the way, in pixels.
const LOOK_REACH: float = 360.0
## Below this ink the eye is not drawn; a gaze or ink change under the steps is not drawn
## again.
const LEAST_INK: float = 0.01
const LOOK_STEP: float = 0.02
const INK_STEP: float = 0.01
const SEED: int = 3307

## The weight the dread layers show the eyes at now, 0 away from the table. One value for
## every back on screen, as the board has one dread.
static var shown: float = 0.0

var _look: Vector2 = Vector2.ZERO
var _drawn_look: Vector2 = Vector2.ZERO
var _drawn_ink: float = 0.0
var _lids: PackedVector2Array = PackedVector2Array()
## The wear the lids were shaped for; shaped again when the stage or the size changes.
var _shaped_wear: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_reshape)


func _process(delta: float) -> void:
	var tuning: DreadEffects = CONFIG.effect_tuning
	var follow: float = 0.0 if UiMotion.reduced() else tuning.follow_share(shown)
	var target: Vector2 = Vector2.ZERO
	if follow > 0.0:
		var away: Vector2 = get_global_mouse_position() - global_position - size * MIDDLE
		target = (away / LOOK_REACH).limit_length(1.0) * follow
	_look = _look.move_toward(target, tuning.eyes_follow_rate * delta)
	var ink: float = ink_for(shown)
	var moved: bool = _look.distance_to(_drawn_look) >= LOOK_STEP
	if moved or absf(ink - _drawn_ink) >= INK_STEP:
		queue_redraw()


## The eye's ink at a weight: none at 0, the data's full ink at 1.
static func ink_for(weight: float) -> float:
	return clampf(weight, 0.0, 1.0) * CONFIG.effect_tuning.eye_ink


## Where the gaze points now, each axis -1 to 1, for tests.
func look() -> Vector2:
	return _look


## The ink the eye was last drawn in, for tests.
func drawn_ink() -> float:
	return _drawn_ink


func _draw() -> void:
	_drawn_ink = ink_for(shown)
	_drawn_look = _look
	if _drawn_ink < LEAST_INK:
		return
	var worn: float = BowlGrime.wear()
	if worn != _shaped_wear:
		_shape_lids(worn)
	var ink: Color = Color(BowlGrime.faded(INK, worn), _drawn_ink)
	var middle: Vector2 = size * MIDDLE
	var width: float = size.x * WIDTH_SHARE
	var tall: float = width * HEIGHT_SHARE
	draw_set_transform(middle)
	draw_polyline(_lids, ink, maxf(1.0, tall * 0.08), true)
	var iris: float = tall * IRIS
	var room: Vector2 = Vector2(width / 2.0 - iris, tall / 2.0 - iris * 0.6) * TURN
	var at: Vector2 = _look * room
	draw_arc(at, iris, 0.0, TAU, 24, ink, maxf(1.0, tall * 0.07), true)
	draw_circle(at, iris * PUPIL, ink)
	# The wet glint comes with the gaze, on paper, never a clean white.
	var glint: float = CONFIG.effect_tuning.follow_share(shown)
	if glint > 0.0:
		var light: Color = Color(BowlGrime.aged(PAPER, worn), _drawn_ink * glint)
		draw_circle(at + Vector2(-0.35, -0.4) * iris * PUPIL, iris * 0.16, light)
	draw_set_transform(Vector2.ZERO)


func _reshape() -> void:
	_shaped_wear = -1.0
	queue_redraw()


## The two lids as one closed line about the eye's middle, a little uneven by a fixed
## seed and more so as the stage wears the print.
func _shape_lids(worn: float) -> void:
	_shaped_wear = worn
	var width: float = size.x * WIDTH_SHARE
	var tall: float = width * HEIGHT_SHARE
	var stray: float = tall * lerpf(LID_STRAY.x, LID_STRAY.y, worn)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	_lids.resize(LID_POINTS * 2 + 1)
	for index: int in LID_POINTS:
		var t: float = float(index) / (LID_POINTS - 1)
		var x: float = lerpf(-width / 2.0, width / 2.0, t)
		var lift: float = sin(PI * t) * tall / 2.0
		_lids[index] = Vector2(x, -lift + rng.randf_range(-stray, stray))
		_lids[LID_POINTS * 2 - 1 - index] = Vector2(x, lift * 0.8 + rng.randf_range(-stray, stray))
	_lids[LID_POINTS * 2] = _lids[0]

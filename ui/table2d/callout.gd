class_name Callout
extends Control
## The table's shout: a slanted banner of red cloth whips across the whole screen, the
## word slams onto it, and it whips off again. A cut-in is the smaller kind, for a
## villager's call, with their face on the cloth. A takeover dims the room and turns
## the poster's sun rays behind the banner, for a bomb or the end of a round. It takes
## the screen on purpose and gives it back within about a second; nothing can be
## clicked while events play, so it never covers a choice. Reduced motion shows the
## same banner without the whip, slam or turning rays.

enum Tier { CUT_IN, TAKEOVER }

const RAYS: int = 28
const BAND_TILT: float = -0.06
const BAND_HEIGHT: Array[float] = [236.0, 330.0]
const WORD_SIZE: Array[int] = [112, 156]
const SUB_SIZE: Array[int] = [30, 36]
const DIM: Array[float] = [0.28, 0.62]
const HOLD: Array[float] = [0.55, 0.85]
const WHIP_IN: float = 0.14
const SLAM: float = 0.2
const WHIP_OUT: float = 0.16
const SLAM_FROM: float = 2.6
const RAY_ALPHA: float = 0.2
const RAY_SPEED: float = 0.45
const EDGE: float = 6.0
const FACE_SIZE: float = 190.0
## How far from the middle a face sits, and how far the word moves over to make room.
const FACE_OFFSET: float = 520.0
const WORD_SHIFT: float = 90.0

## How far the cloth has crossed, how far it has left, and how strong the dim and rays
## are, each from 0 to 1. Tweened; the banner is drawn from them.
var wipe: float = 0.0
var leave: float = 0.0
var glow: float = 0.0

var _tier: Tier = Tier.CUT_IN
var _cloth: Color = Color.WHITE
var _from_left: bool = true
var _spin: float = 0.0
var _word: Label = Label.new()
var _sub: Label = Label.new()
var _face: TextureRect = TextureRect.new()
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label: Label in [_word, _sub]:
		label.theme_type_variation = CommonsTheme.TITLE
		label.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
		label.add_theme_color_override("font_outline_color", ScreenKit.INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.rotation = BAND_TILT
		add_child(label)
	_word.add_theme_constant_override("outline_size", 18)
	_sub.add_theme_constant_override("outline_size", 8)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_face.size = Vector2.ONE * FACE_SIZE
	_face.pivot_offset = _face.size / 2.0
	_face.rotation = BAND_TILT
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	_rest()


## Shouts word across the screen on cloth of a color, with a line under it and, for a
## villager, their face on the side they sit. Returns the seconds it takes the screen.
func shout(
	word: String,
	tier: Tier,
	cloth: Color,
	sub: String = "",
	face: Texture2D = null,
	from_left: bool = true
) -> float:
	_rest()
	_tier = tier
	_cloth = cloth
	_from_left = from_left
	_lay_out(word.to_upper(), sub, face)
	visible = true
	set_process(true)
	var hold: float = UiMotion.seconds(HOLD[tier])
	_tween = create_tween().set_parallel(true)
	if UiMotion.reduced():
		wipe = 1.0
		glow = 1.0
		_tween.tween_interval(hold)
		_tween.chain().tween_callback(_rest)
		queue_redraw()
		return hold
	_word.scale = Vector2.ONE * SLAM_FROM
	_word.modulate.a = 0.0
	_sub.modulate.a = 0.0
	var side: float = -1.0 if from_left else 1.0
	var face_rest: Vector2 = _face.position
	_face.position.x += side * size.x * 0.4
	_tween.tween_property(self, "glow", 1.0, WHIP_IN)
	_tween.tween_property(self, "wipe", 1.0, WHIP_IN).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_property(_face, "position", face_rest, SLAM).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	var slam: PropertyTweener = _tween.tween_property(_word, "scale", Vector2.ONE, SLAM)
	slam.set_delay(WHIP_IN * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_word, "modulate:a", 1.0, SLAM * 0.4).set_delay(WHIP_IN * 0.5)
	_tween.tween_property(_sub, "modulate:a", 1.0, SLAM).set_delay(WHIP_IN + SLAM * 0.5)
	_tween.chain().tween_interval(hold)
	var out: PropertyTweener = _tween.chain().tween_property(self, "leave", 1.0, WHIP_OUT)
	out.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "glow", 0.0, WHIP_OUT)
	for part: Control in [_word, _sub, _face]:
		_tween.tween_property(part, "modulate:a", 0.0, WHIP_OUT * 0.7)
		_tween.tween_property(part, "position:x", part.position.x - side * 260.0, WHIP_OUT)
	_tween.chain().tween_callback(_rest)
	return WHIP_IN + SLAM + hold + WHIP_OUT


## Takes the banner down at once.
func dismiss() -> void:
	_rest()


func is_showing() -> bool:
	return visible


## The word now on the banner, or "" when it is down. For tests.
func shown_word() -> String:
	return _word.text if visible else ""


func shown_sub() -> String:
	return _sub.text if visible else ""


func _process(delta: float) -> void:
	_spin += delta * RAY_SPEED
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var middle: Vector2 = size / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(ScreenKit.INK, DIM[_tier] * glow))
	if _tier == Tier.TAKEOVER:
		_draw_rays(middle)
	draw_set_transform(middle, BAND_TILT)
	var half: float = size.x * 0.75
	var tall: float = BAND_HEIGHT[_tier]
	var from: float = -half + 2.0 * half * leave
	var to: float = -half + 2.0 * half * wipe
	if not _from_left:
		var flipped: float = -from
		from = -to
		to = flipped
	if to > from:
		var cloth: Rect2 = Rect2(from, -tall / 2.0, to - from, tall)
		draw_rect(cloth, _cloth)
		var trim: Color = ScreenKit.STYLE.paper_bright
		draw_rect(Rect2(from, -tall / 2.0 + EDGE * 2.0, to - from, EDGE), trim)
		draw_rect(Rect2(from, tall / 2.0 - EDGE * 3.0, to - from, EDGE), trim)
	draw_set_transform(Vector2.ZERO, 0.0)


## The poster's sun rays, every other wedge of a turning wheel behind the banner.
func _draw_rays(middle: Vector2) -> void:
	var reach: float = size.length()
	var wedge: float = TAU / RAYS
	var ink: Color = Color(ScreenKit.STYLE.paper_bright, RAY_ALPHA * glow)
	for ray: int in range(0, RAYS, 2):
		var angle: float = _spin + wedge * ray
		var points: PackedVector2Array = PackedVector2Array(
			[
				middle,
				middle + Vector2.from_angle(angle) * reach,
				middle + Vector2.from_angle(angle + wedge) * reach,
			]
		)
		draw_colored_polygon(points, ink)


func _lay_out(word: String, sub: String, face: Texture2D) -> void:
	var middle: Vector2 = size / 2.0
	var tall: float = BAND_HEIGHT[_tier]
	var side: float = -1.0 if _from_left else 1.0
	_face.texture = face
	_face.visible = face != null
	_face.position = middle + Vector2(side * FACE_OFFSET, 0) - _face.size / 2.0
	var shift: float = -side * WORD_SHIFT if face != null else 0.0
	_word.text = word
	_word.add_theme_font_size_override("font_size", WORD_SIZE[_tier])
	_sub.text = sub
	_sub.add_theme_font_size_override("font_size", SUB_SIZE[_tier])
	for label: Label in [_word, _sub]:
		label.reset_size()
		label.pivot_offset = label.size / 2.0
	var lift: float = tall * 0.1 if not sub.is_empty() else 0.0
	_word.position = middle + Vector2(shift, -lift) - _word.size / 2.0
	_sub.position = middle + Vector2(shift, tall * 0.3) - _sub.size / 2.0


func _rest() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	wipe = 0.0
	leave = 0.0
	glow = 0.0
	visible = false
	set_process(false)
	for part: Control in [_word, _sub, _face]:
		part.modulate.a = 1.0
		part.scale = Vector2.ONE

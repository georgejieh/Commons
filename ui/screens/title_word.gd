class_name TitleWord
extends Control
## The game's name on the title, printed the way the poster behind it was: ink for the
## key line, a vermilion pass and the gold over it. It is the title's one moment
## (art/STYLE.md, Motion): each letter is pressed down from large to its place, one
## after another, and stays. Nothing is clean: at stage 0 the type sits a hair uneven and
## the vermilion pass is a little out of register, and each corruption stage sets both
## further off. Under reduced motion the word stands printed at once.

const SIZE: int = 168
const OUTLINE: int = 20
## The face keeps room over its capitals and under its line that this word has no use
## for. These shares of the size are left off its box, so the lines above and below sit
## as close to it as they do to each other.
const HEAD: float = 0.26
const FOOT: float = 0.2
## How far a letter sits off its line and off upright at stage 0, in pixels and radians,
## and how much further each stage sets it.
const DROP: float = 1.5
const LEAN: float = 0.007
const WORSE_PER_STAGE: float = 0.35
## How far the vermilion pass lies out of register: at rest at stage 0, more per stage,
## and as its letter lands.
const SLIP: float = 3.0
const SLIP_PER_STAGE: float = 0.5
const SLIP_LANDING: float = 9.0
const SLIP_ALONG: Vector2 = Vector2(1.0, 0.6)
## A letter comes down turned by up to this much.
const TURN: float = 0.06
const SEED: int = 5179

## The word it prints.
var text: String = ""
## Seconds into the pressing. Letters land as it passes them.
var clock: float = 0.0:
	set(value):
		clock = value
		queue_redraw()

var _font: Font = ScreenKit.DISPLAY_BOLD
## Each letter's seeded drop, lean and landing turn, as shares of DROP, LEAN and TURN.
var _set: Array[Vector3] = []


func _init(word: String) -> void:
	text = word
	accessibility_name = word
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its box is the word and no wider, so what stands beside it is clear of it.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = SEED
	for _letter: int in text.length():
		var drop: float = random.randf_range(-1.0, 1.0)
		var lean: float = random.randf_range(-1.0, 1.0)
		_set.append(Vector3(drop, lean, random.randf_range(-1.0, 1.0)))
	clock = seconds()


func _get_minimum_size() -> Vector2:
	var px: int = TextSize.px(SIZE)
	var wide: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	return Vector2(wide, _font.get_height(px) - (HEAD + FOOT) * px)


## How long the whole word takes to press.
func seconds() -> float:
	var presets: MotionPresets = UiMotion.PRESETS
	return presets.letter_stagger * maxi(text.length() - 1, 0) + presets.letter_time


## Presses the word after delay seconds. Returns how long after the delay its last
## letter starts down, which is when the next piece of the page may follow; 0 under
## reduced motion, where the word is printed already.
func press(delay: float) -> float:
	if UiMotion.reduced():
		return 0.0
	clock = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Audio.fill.bind(AudioEvents.MOTION_STAMP))
	tween.tween_property(self, "clock", seconds(), seconds())
	return seconds() - UiMotion.PRESETS.letter_time


## Whether every letter is down.
func is_printed() -> bool:
	return clock >= seconds()


## How far a letter has come down, 0 to 1.
func landed(letter: int) -> float:
	var presets: MotionPresets = UiMotion.PRESETS
	return clampf((clock - letter * presets.letter_stagger) / presets.letter_time, 0.0, 1.0)


## How far the vermilion pass lies out of register at rest at a corruption stage.
static func slip(stage: int) -> float:
	return SLIP + SLIP_PER_STAGE * stage


## How uneven the type sits at a corruption stage, as a multiple of stage 0.
static func unevenness(stage: int) -> float:
	return 1.0 + WORSE_PER_STAGE * stage


func _draw() -> void:
	var px: int = TextSize.px(SIZE)
	var stage: int = ArtStages.art_stage()
	# The ink under every letter first, then the vermilion, then the gold, as a label
	# lays its outline under all of its type.
	for layer: int in 3:
		for letter: int in text.length():
			if landed(letter) > 0.0:
				_draw_letter(layer, letter, px, stage)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_letter(layer: int, letter: int, px: int, stage: int) -> void:
	var presets: MotionPresets = UiMotion.PRESETS
	var down: float = landed(letter)
	var pressed: float = Tween.interpolate_value(
		0.0, 1.0, down, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT
	)
	var glyph: String = text[letter]
	var upto: String = text.substr(0, letter + 1)
	var wide: float = _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var left: float = _font.get_string_size(upto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x - wide
	var uneven: float = unevenness(stage)
	var rest: Vector3 = _set[letter]
	var middle: Vector2 = Vector2(left + wide / 2.0, size.y / 2.0 + rest.x * DROP * uneven)
	var turn: float = lerpf(rest.z * TURN, rest.y * LEAN * uneven, minf(pressed, 1.0))
	var grown: float = lerpf(presets.letter_from_scale, 1.0, pressed)
	draw_set_transform(middle, turn, Vector2.ONE * grown)
	var at: Vector2 = Vector2(-wide / 2.0, _font.get_ascent(px) - HEAD * px - size.y / 2.0)
	var ink: float = minf(down * 2.5, 1.0)
	match layer:
		0:
			draw_char_outline(_font, at, glyph, px, OUTLINE, Color(ScreenKit.INK, ink))
		1:
			var off: float = lerpf(SLIP_LANDING, slip(stage), ease(down, 0.3))
			draw_char(_font, at + SLIP_ALONG * off, glyph, px, Color(ScreenKit.RED, ink))
		2:
			draw_char(_font, at, glyph, px, Color(ScreenKit.GOLD, ink))

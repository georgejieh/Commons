class_name ScoreTally
extends HBoxContainer
## How a play's score is made, shown under the trick on four small paper chits: Grain ×
## Rate × Zeal = the total. ScoreSequence drives it a figure at a time (P5.2a): Grain
## counts up as the cards are counted, Rate and Zeal are stamped on, each change bumps its
## figure, then the total rolls up and lands, and landed fires so the table can send it to
## the ledger. show_score() sets the whole sum at once. Chits are made once; the tally only
## scales and fades its chits, and shakes as a whole, so the table can keep all its
## motion inside the room it gives it.

signal landed(total_text: String)

const PRESETS: MotionPresets = preload("res://data/ui/motion_presets.tres")
## A chit's least size, and its padding inside the paper's printed border.
const TILE: Vector2 = Vector2(96, 70)
const PADDING: int = 18
const VALUE_SIZE: int = 26
const TOTAL_SIZE: int = 30
const SIGN_SIZE: int = 24
## The caption under each figure, smaller than the theme's eyebrow so the chit stays low.
const CAPTION_SIZE: int = 14
const GAP: int = 6
## How long the total stands once it lands before the tally fades. HELD is the share of
## that the table waits through, so the next play never starts over a total not yet read.
const LINGER: float = 0.9
const HELD: float = 0.5
const FADE: float = 0.2
const TOTAL_INK: Color = Color("9e1b16")
const IDLE: Color = Color("8a745c")
const WORDS: PackedStringArray = ["grain", "rate", "zeal"]
const WHOLE: int = 100
## The chits by place: Grain, Rate, Zeal, then the total.
const GRAIN: int = 0
const RATE: int = 1
const ZEAL: int = 2
const TOTAL: int = 3

var _values: Array[Label] = []
var _tiles: Array[Control] = []
var _equals: Label
var _tween: Tween = null
var _shake: Tween = null
## Where the tally rests; it shakes about this point.
var _rest: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", GAP)
	for index: int in WORDS.size():
		if index > 0:
			add_child(_sign("×"))
		var ink: Color = Color(Keywords.INKS[WORDS[index]])
		_add_tile(tr("keyword.%s.name" % WORDS[index]), ink, VALUE_SIZE)
	_equals = _sign("=")
	add_child(_equals)
	_add_tile(tr("tally.total"), TOTAL_INK, TOTAL_SIZE)
	visible = false


## Sets the whole sum at once and fades it after a while, as a replay or a test wants.
## pace scales nothing here; it is kept so callers need not change. Returns 0.
func show_score(grain: float, rate: float, zeal: float, total: float, _pace: float = 1.0) -> float:
	begin(zeal)
	figure(GRAIN, Strings.score(grain), false)
	figure(RATE, Strings.factor(rate), false)
	figure(ZEAL, Strings.factor(zeal), false)
	scaled(ScoreTally.scale_percent(grain, rate, zeal, total))
	var total_text: String = Strings.score(total)
	figure(TOTAL, total_text, false)
	landed.emit(total_text)
	fade_after(LINGER)
	return 0.0


## Shows the tally with its chits empty, about to be filled. A final Zeal of 1 changes
## nothing, so its chit is inked quietly.
func begin(final_zeal: float) -> void:
	_stop()
	visible = true
	modulate.a = 1.0
	_equals.text = "="
	_values[ZEAL].add_theme_color_override(
		"font_color", IDLE if is_equal_approx(final_zeal, 1.0) else Color(Keywords.INKS["zeal"])
	)
	for index: int in _tiles.size():
		_values[index].text = ""
		_values[index].custom_minimum_size.x = 0.0
		_tiles[index].modulate.a = 0.0


## Keeps a chit wide enough for the widest of texts, every digit as wide as the widest, so
## the tally holds its size and place while its figures change.
func reserve(index: int, texts: Array[String]) -> void:
	var label: Label = _values[index]
	for text: String in texts:
		label.custom_minimum_size.x = maxf(
			label.custom_minimum_size.x, UiMotion.widest(label, text)
		)


## Puts a figure on its chit. bump swells the chit and lets it settle, unless motion is
## reduced; landing larger, for the total, takes score_total_scale.
func figure(index: int, text: String, bump: bool, big: bool = false) -> void:
	_values[index].text = text
	var tile: Control = _tiles[index]
	tile.modulate.a = 1.0
	if not bump or UiMotion.reduced():
		tile.scale = Vector2.ONE
		return
	tile.pivot_offset = tile.size / 2.0
	tile.scale = Vector2.ONE * (PRESETS.score_total_scale if big else PRESETS.score_chit_scale)
	var press: Tween = tile.create_tween()
	press.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	press.tween_property(tile, "scale", Vector2.ONE, PRESETS.score_stamp)


## The equals sign says what share of Grain × Rate × Zeal a cut left the total.
func scaled(percent: int) -> void:
	_equals.text = "=" if percent == WHOLE else tr("tally.scaled").format({"percent": percent})


## The total has landed: the table may send it on.
func land(total_text: String) -> void:
	landed.emit(total_text)


## Shakes the tally about its rest by up to pixels, dying away over seconds.
func shake(pixels: float, seconds: float) -> void:
	if pixels <= 0.0 or UiMotion.reduced():
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	_rest = position
	_shake = create_tween()
	var hops: int = 4
	for hop: int in hops:
		var side: float = -1.0 if hop % 2 == 0 else 1.0
		var reach: float = pixels * (1.0 - float(hop) / hops)
		_shake.tween_property(self, "position", _rest + Vector2(side * reach, 0.0), seconds / hops)
	_shake.tween_property(self, "position", _rest, seconds / hops)


## How far any motion here takes a chit past its resting box, on each side, in pixels.
func reach() -> Vector2:
	var most: float = maxf(PRESETS.score_chit_scale, PRESETS.score_total_scale) - 1.0
	var widest: float = 0.0
	for tile: Control in _tiles:
		widest = maxf(widest, tile.size.x)
	return Vector2(widest * most / 2.0 + PRESETS.score_shake, size.y * most / 2.0)


## Fades the tally away after a while.
func fade_after(after: float) -> void:
	_tween = create_tween()
	_tween.tween_interval(after)
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)


## Seconds after the total lands that the table waits before its next event.
static func read_time(pace: float) -> float:
	return LINGER * HELD * minf(pace, 1.0)


func clear() -> void:
	_stop()
	visible = false


## What a hook left of a play's total, in percent of Grain × Rate × Zeal: 100 when the
## total is the plain product, 50 under a debuff that halves it, 0 when it scores nothing.
static func scale_percent(grain: float, rate: float, zeal: float, total: float) -> int:
	var product: float = grain * rate * zeal
	if product <= 0.0 or is_equal_approx(product, total):
		return WHOLE
	return roundi(WHOLE * total / product)


## Where a chit sits on screen, its middle.
func tile_center(index: int) -> Vector2:
	var tile: Control = _tiles[index]
	return tile.global_position + tile.size / 2.0


## Where the total sits on screen, its middle.
func total_center() -> Vector2:
	return tile_center(TOTAL)


## Each chit's box on screen as it is drawn now, its scale included, for tests.
func drawn_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for tile: Control in _tiles:
		var box: Rect2 = Rect2(Vector2.ZERO, tile.size)
		rects.append(tile.get_global_transform() * box)
	return rects


## The chits as plain text, such as "54 × 7 × 1 = 378", for tests.
func shown() -> String:
	if not visible:
		return ""
	var parts: Array[String] = [
		_values[0].text, _values[1].text, _values[2].text, _equals.text, _values[3].text
	]
	return "%s × %s × %s %s %s" % parts


func _stop() -> void:
	for running: Tween in [_tween, _shake]:
		if running != null and running.is_valid():
			running.kill()
	if _shake != null:
		position = _rest
	_tween = null
	_shake = null
	for tile: Control in _tiles:
		tile.scale = Vector2.ONE


func _add_tile(caption: String, ink: Color, value_size: int) -> void:
	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = TILE
	tile.add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	var value: Label = Label.new()
	value.theme_type_variation = CommonsTheme.TITLE
	value.add_theme_font_size_override("font_size", TextSize.px(value_size))
	value.add_theme_color_override("font_color", ink)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	var name: Label = Label.new()
	name.text = caption.to_upper()
	name.theme_type_variation = CommonsTheme.EYEBROW
	name.add_theme_font_size_override("font_size", TextSize.px(CAPTION_SIZE))
	name.add_theme_color_override("font_color", ink)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	box.add_child(name)
	tile.add_child(box)
	add_child(tile)
	_tiles.append(tile)
	_values.append(value)


func _sign(text: String) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.theme_type_variation = CommonsTheme.TITLE
	made.add_theme_font_size_override("font_size", TextSize.px(SIGN_SIZE))
	made.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	ScreenKit.paper_outline(made)
	made.add_theme_color_override("font_outline_color", ScreenKit.INK)
	return made

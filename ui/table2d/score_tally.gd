class_name ScoreTally
extends HBoxContainer
## How a play's score is made, acted out under the trick: three paper chits for Grain,
## Rate and Zeal fill in one after another, then the total rolls up and lands. Grain
## counts up as the cards are counted, Rate and Zeal are stamped on, and landed fires
## when the total is in, so the table can send it to the ledger. Chits are made once.

signal landed(total_text: String)

const TILE: Vector2 = Vector2(128, 84)
const VALUE_SIZE: int = 40
const TOTAL_SIZE: int = 48
const SIGN_SIZE: int = 34
## Seconds for each beat at full pace: chits in, Grain counting, a stamp, the total.
const ENTER: float = 0.08
const COUNT: float = 0.26
const BEAT: float = 0.12
const ROLL: float = 0.24
const LINGER: float = 0.7
const STAMP_SCALE: float = 1.35
const TOTAL_INK: Color = Color("9e1b16")
const IDLE: Color = Color("8a745c")
const WORDS: PackedStringArray = ["grain", "rate", "zeal"]
const WHOLE: int = 100

var _values: Array[Label] = []
var _tiles: Array[Control] = []
var _total: Label = Label.new()
var _total_tile: Control
var _equals: Label
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	for index: int in WORDS.size():
		if index > 0:
			add_child(_sign("×"))
		var value: Label = Label.new()
		var ink: Color = Color(Keywords.INKS[WORDS[index]])
		_tiles.append(_tile(value, tr("keyword.%s.name" % WORDS[index]), ink, VALUE_SIZE))
		_values.append(value)
	_equals = _sign("=")
	add_child(_equals)
	_total_tile = _tile(_total, tr("tally.total"), TOTAL_INK, TOTAL_SIZE)
	visible = false


## Acts out a play's score. pace scales every beat: 1 for the player's own play, less
## for a villager's. Returns the seconds until the total lands.
func show_score(grain: float, rate: float, zeal: float, total: float, pace: float = 1.0) -> float:
	_stop()
	visible = true
	modulate.a = 1.0
	var texts: PackedStringArray = [
		Strings.score(grain), Strings.factor(rate), Strings.factor(zeal)
	]
	var total_text: String = Strings.score(total)
	# A debuff that cuts the total shows as a last factor, so the sum still adds up.
	var percent: int = ScoreTally.scale_percent(grain, rate, zeal, total)
	_equals.text = "=" if percent == WHOLE else tr("tally.scaled").format({"percent": percent})
	# A Zeal of 1 changes nothing, so its chit stays quiet.
	_values[2].add_theme_color_override(
		"font_color", IDLE if is_equal_approx(zeal, 1.0) else Color(Keywords.INKS["zeal"])
	)
	if UiMotion.reduced() or pace <= 0.0:
		for index: int in _values.size():
			_values[index].text = texts[index]
			_tiles[index].modulate.a = 1.0
		_total.text = total_text
		_total_tile.modulate.a = 1.0
		landed.emit(total_text)
		_fade(LINGER)
		return 0.0
	for index: int in _values.size():
		_values[index].text = "" if index > 0 else Strings.score(0.0)
		_tiles[index].modulate.a = 0.0
	_total.text = ""
	_total_tile.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_tiles[0], "modulate:a", 1.0, ENTER * pace)
	_tween.tween_method(_count.bind(_values[0]), 0.0, grain, COUNT * pace)
	for index: int in [1, 2]:
		_tween.tween_callback(_stamp.bind(_tiles[index], _values[index], texts[index]))
		_tween.tween_interval(BEAT * pace)
	_tween.tween_callback(_stamp.bind(_total_tile, _total, Strings.score(0.0)))
	_tween.tween_method(_count.bind(_total), 0.0, total, ROLL * pace)
	_tween.tween_callback(_land.bind(total_text))
	_tween.tween_interval(LINGER)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(hide)
	return (ENTER + COUNT + BEAT * 2.0 + ROLL) * pace


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


## Where the total sits on screen, its middle.
func total_center() -> Vector2:
	return _total_tile.global_position + _total_tile.size / 2.0


## The chits as plain text, such as "54 × 7 × 1 = 378", for tests.
func shown() -> String:
	if not visible:
		return ""
	var parts: Array[String] = [
		_values[0].text, _values[1].text, _values[2].text, _equals.text, _total.text
	]
	return "%s × %s × %s %s %s" % parts


func _count(value: float, label: Label) -> void:
	label.text = Strings.score(value)


func _stamp(tile: Control, label: Label, text: String) -> void:
	label.text = text
	tile.modulate.a = 1.0
	tile.pivot_offset = tile.size / 2.0
	tile.scale = Vector2.ONE * STAMP_SCALE
	var press: Tween = tile.create_tween()
	press.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	press.tween_property(tile, "scale", Vector2.ONE, BEAT)


func _land(total_text: String) -> void:
	_total.text = total_text
	_stamp(_total_tile, _total, total_text)
	landed.emit(total_text)


func _fade(after: float) -> void:
	_tween = create_tween()
	_tween.tween_interval(after)
	_tween.tween_callback(hide)


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	for tile: Control in _tiles:
		tile.scale = Vector2.ONE
	_total_tile.scale = Vector2.ONE


func _tile(value: Label, caption: String, ink: Color, value_size: int) -> Control:
	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = TILE
	tile.add_theme_stylebox_override("panel", ScreenKit.paper_style(8))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	value.theme_type_variation = CommonsTheme.TITLE
	value.add_theme_font_size_override("font_size", value_size)
	value.add_theme_color_override("font_color", ink)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	var name: Label = Label.new()
	name.text = caption.to_upper()
	name.theme_type_variation = CommonsTheme.EYEBROW
	name.add_theme_color_override("font_color", ink)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	box.add_child(name)
	tile.add_child(box)
	add_child(tile)
	return tile


func _sign(text: String) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.theme_type_variation = CommonsTheme.TITLE
	made.add_theme_font_size_override("font_size", SIGN_SIZE)
	made.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	ScreenKit.paper_outline(made)
	made.add_theme_color_override("font_outline_color", ScreenKit.INK)
	return made

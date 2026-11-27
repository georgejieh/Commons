class_name QuotaBar
extends ProgressBar
## The Quota as a bar of grain with the count written on it. It fills as work points
## arrive, turns gold once the Quota is met and is sealed "met"; a Quota that ends short
## is sealed in black. The table's top bar and the Quota report both show one.

signal filled

const GRAIN: Color = Color("c8952b")
const MET: Color = Color("e0b23c")
const GROUND: Color = Color("4a4239")
const PAPER: Color = Color("efe3c8")
const INK: Color = Color("1e1a16")

var _text: Label = Label.new()
var _fill: StyleBoxFlat = StyleBoxFlat.new()
var _seal: InkSeal = InkSeal.new()
var _target: float = 1.0
var _shown: float = 0.0
var _tween: Tween = null


func _init() -> void:
	show_percentage = false
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ground: StyleBoxFlat = StyleBoxFlat.new()
	ground.bg_color = GROUND
	add_theme_stylebox_override("background", ground)
	_fill.bg_color = GRAIN
	add_theme_stylebox_override("fill", _fill)
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_text.add_theme_color_override("font_color", PAPER)
	_text.add_theme_color_override("font_outline_color", INK)
	_text.add_theme_constant_override("outline_size", 6)
	add_child(_text)
	add_child(_seal)


## Sizes the bar, its count and its seal, which overhangs the bar's right end.
func setup(bar_size: Vector2, seal_width: float, font_size: int) -> void:
	custom_minimum_size = bar_size
	_text.add_theme_font_size_override("font_size", font_size)
	_seal.prepare(tr("table.quota_met"), ScreenKit.RED, seal_width)
	_seal.position = Vector2(bar_size.x - seal_width * 0.6, (bar_size.y - seal_width) / 2.0)
	show_value(_shown)


func set_target(target: float) -> void:
	_target = maxf(target, 1.0)
	show_value(_shown)


## Shows a value at once: the fill, the count, and the seal once it reaches the target.
func show_value(shown: float) -> void:
	_shown = shown
	var met: bool = shown >= _target
	max_value = _target
	value = minf(shown, _target)
	_fill.bg_color = MET if met else GRAIN
	_text.text = tr("table.quota").format(
		{"progress": Strings.score(shown), "target": Strings.score(_target)}
	)
	if met and not _seal.visible:
		_seal.prepare(tr("table.quota_met"), ScreenKit.RED, _seal.size.x)
		_seal.press()
	elif not met:
		_seal.visible = false


## Fills from what is shown to a value over seconds, after a delay, then says filled.
## Reduced motion shows it at once.
func fill_to(to: float, seconds: float, delay: float = 0.0) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if UiMotion.reduced() or seconds <= 0.0:
		show_value(to)
		filled.emit()
		return
	_tween = create_tween()
	_tween.tween_interval(delay)
	var fill: MethodTweener = _tween.tween_method(show_value, _shown, to, seconds)
	fill.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(filled.emit)


## Seals a Quota that ended short, in black.
func seal_short() -> void:
	_seal.prepare(tr("summary.short"), INK, _seal.size.x)
	_seal.press()


func is_met() -> bool:
	return _shown >= _target


## The word on the seal, or "" while there is none. For tests.
func seal_word() -> String:
	return _seal.word() if _seal.visible else ""

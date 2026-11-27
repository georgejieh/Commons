class_name QuotaBar
extends ProgressBar
## The Quota as a bar of grain with the count written on it. It fills as work points
## arrive, turns gold once the Quota is met and is sealed "met"; a Quota that ends short
## is sealed in black. The table's top bar and the Quota report both show one. It shows
## its figures as ShownFigures says (ADR 0022): as they are, without the target under a
## dark norm (no fill and no seal, so nothing gives the target away), or as fulfilled at
## the stage past the last.

## Emitted when fill_to has shown its value, at once under reduced motion; the report waits on it.
signal filled

## How the bar shows its figures: as they are, without the target, or as fulfilled.
enum Shown { AS_IS, NO_TARGET, FULFILLED }

## The seal pressed on the bar once the Quota is met.
var seal: InkSeal = InkSeal.new()
var _text: Label = Label.new()
var _fill: StyleBoxFlat = StyleBoxFlat.new()
var _target: float = 1.0
var _shown: float = 0.0
var _tween: Tween = null
var _mode: Shown = Shown.AS_IS


func _init() -> void:
	show_percentage = false
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ground: StyleBoxFlat = StyleBoxFlat.new()
	ground.bg_color = ScreenKit.BAR_GROUND
	add_theme_stylebox_override("background", ground)
	_fill.bg_color = ScreenKit.GRAIN_BAR
	add_theme_stylebox_override("fill", _fill)
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_text.add_theme_color_override("font_color", ScreenKit.PAPER)
	_text.add_theme_color_override("font_outline_color", ScreenKit.INK)
	_text.add_theme_constant_override("outline_size", 6)
	add_child(_text)
	add_child(seal)


## Sizes the bar, its count and its seal, which overhangs the bar's right end.
func setup(bar_size: Vector2, seal_width: float, font_size: int) -> void:
	custom_minimum_size = bar_size
	_text.add_theme_font_size_override("font_size", TextSize.px(font_size))
	seal.prepare(tr("table.quota_met"), ScreenKit.RED, seal_width)
	seal.position = Vector2(bar_size.x - seal_width * 0.6, (bar_size.y - seal_width) / 2.0)
	show_value(_shown)


## Sets the Quota the bar fills toward, at least 1, and draws the count and seal again.
func set_target(target: float) -> void:
	_target = maxf(target, 1.0)
	show_value(_shown)


## How the bar shows its figures from now on.
func show_as(mode: Shown) -> void:
	if mode != _mode:
		_mode = mode
		show_value(_shown)


## The bar's way of showing its figures for a run state, by ShownFigures.
static func mode_for(state: RunView) -> Shown:
	if ShownFigures.all_success():
		return Shown.FULFILLED
	return Shown.AS_IS if ShownFigures.shows_target(state) else Shown.NO_TARGET


## Shows a value at once: the fill, the count, and the seal once it reaches the target.
func show_value(shown: float) -> void:
	_shown = shown
	var met: bool = shown >= _target
	max_value = _target
	value = minf(shown, _target)
	_fill.bg_color = ScreenKit.GLOW if met else ScreenKit.GRAIN_BAR
	_text.text = tr("table.quota").format(
		{"progress": Strings.score(shown), "target": Strings.score(_target)}
	)
	if _mode == Shown.NO_TARGET:
		value = 0.0
		_text.text = tr(ShownFigures.QUOTA_DARK).format({"progress": Strings.score(shown)})
		seal.visible = false
		return
	if _mode == Shown.FULFILLED:
		met = true
		value = _target
		_fill.bg_color = ScreenKit.GLOW
		_text.text = tr(ShownFigures.FULFILLED)
	if met and not seal.visible:
		seal.prepare(tr("table.quota_met"), ScreenKit.RED, seal.size.x)
		seal.press()
	elif not met:
		seal.visible = false


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
	_tween.tween_callback(Audio.fill.bind(AudioEvents.MOTION_COUNT))
	var fill: MethodTweener = _tween.tween_method(show_value, _shown, to, seconds)
	fill.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(filled.emit)


## Seals a Quota that ended short, in black, unless the bar reads it as fulfilled.
func seal_short() -> void:
	if _mode == Shown.FULFILLED:
		return
	seal.prepare(tr("summary.short"), ScreenKit.INK, seal.size.x)
	seal.press()


## True once the value shown has reached the target.
func is_met() -> bool:
	return _shown >= _target


## The words written on the bar, for tests.
func text() -> String:
	return _text.text


## The word on the seal, or "" while there is none. For tests.
func seal_word() -> String:
	return seal.word() if seal.visible else ""

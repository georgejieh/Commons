class_name TableHud
extends PanelContainer
## The bar across the top of the table: where you are in the run, the Quota as a bar
## that fills as work points reach you and is sealed when met, both meters and your
## coupons. It reads a copy of the run state and never changes it.

const INK: Color = Color("1e1a16")
const PAPER: Color = Color("efe3c8")
const GRAIN: Color = Color("c8952b")
const ZEAL: Color = Color("c8341e")
const COUPON: Color = Color("6f9a62")

## The sizes of the bars.
const QUOTA_BAR: Vector2 = Vector2(300, 30)
const METER_BAR: Vector2 = Vector2(150, 18)
const SEAL_WIDTH: float = 92.0
## Seconds a bar takes to reach a new value.
const FILL_TIME: float = 0.6
const QUOTA: String = "quota"
const FAMINE: String = "famine"
const DENUNCIATION: String = "denunciation"

var status: Label = Label.new()
var coupons: Label = Label.new()
var quota: QuotaBar = QuotaBar.new()
var famine: ProgressBar = ProgressBar.new()
var denunciation: ProgressBar = ProgressBar.new()
var menu: Button = Button.new()

var _target: float = 1.0
## Where each bar is heading: the Quota's progress and both meters.
var _goals: Dictionary[String, float] = {QUOTA: 0.0, FAMINE: 0.0, DENUNCIATION: 0.0}
var _tweens: Dictionary[String, Tween] = {}


func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = INK
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	status.add_theme_color_override("font_color", PAPER)
	status.add_theme_font_size_override("font_size", 26)
	status.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	row.add_child(status)
	row.add_child(_quota_box())
	row.add_child(_meter("meter.famine", famine, GRAIN, ScreenKit.ART.icon_famine))
	row.add_child(_meter("meter.denunciation", denunciation, ZEAL, ScreenKit.ART.icon_denunciation))
	row.add_child(_icon(ScreenKit.ART.icon_coupon))
	coupons.add_theme_color_override("font_color", COUPON)
	coupons.add_theme_font_size_override("font_size", 26)
	coupons.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	row.add_child(coupons)
	menu.text = tr("pause.open")
	menu.theme_type_variation = CommonsTheme.GHOST
	menu.add_theme_font_size_override("font_size", 18)
	menu.tooltip_text = tr("pause.open_tip")
	UiMotion.hoverable(menu)
	row.add_child(menu)
	add_child(row)


## Where the run stands and the coupons held. The bars move through sync() and the
## events that change them, so they fill when the points arrive, not before.
func show_state(state: RunState, rounds: int) -> void:
	status.text = (
		tr("table.status")
		. format(
			{
				"year": state.year,
				"set": tr("set.type.%d" % state.set_type),
				"round": mini(state.round_index + 1, rounds),
				"rounds": rounds,
			}
		)
	)
	coupons.text = Strings.count("table.coupons", state.coupons)


## Puts every bar where the run says it is, at once, unless it is already heading there.
func sync(state: RunState, target: float) -> void:
	if not is_equal_approx(_target, maxf(target, 1.0)):
		_target = maxf(target, 1.0)
		quota.set_target(_target)
	_move(QUOTA, state.set_progress, false)
	_move(FAMINE, state.famine, false)
	_move(DENUNCIATION, state.denunciation, false)


## A new Quota: the bar empties and takes its target.
func start_quota(target: float) -> void:
	_target = maxf(target, 1.0)
	quota.set_target(_target)
	_goals[QUOTA] = -1.0
	_move(QUOTA, 0.0, false)


## Work points reached the player: the Quota bar fills by amount after a delay, the
## time the number takes to fly over.
func add_progress(amount: float, delay: float = 0.0) -> void:
	_move(QUOTA, _goals[QUOTA] + amount, true, delay)


## A meter moved by delta.
func nudge_meter(meter: String, delta: float) -> void:
	if _goals.has(meter) and meter != QUOTA:
		_move(meter, _goals[meter] + delta, true)


## Where the Quota bar sits on screen, its middle.
func progress_center() -> Vector2:
	return quota.global_position + quota.size / 2.0


## Where a bar is heading, for tests.
func goal(bar: String) -> float:
	return _goals[bar]


func is_met() -> bool:
	return quota.is_met()


func _move(bar: String, value: float, animate: bool, delay: float = 0.0) -> void:
	if is_equal_approx(_goals[bar], value):
		return
	var from: float = maxf(_goals[bar], 0.0)
	_goals[bar] = value
	if _tweens.has(bar) and _tweens[bar] != null and _tweens[bar].is_valid():
		_tweens[bar].kill()
	if not animate or UiMotion.reduced():
		_show(value, bar)
		return
	var tween: Tween = create_tween()
	_tweens[bar] = tween
	tween.tween_interval(delay)
	tween.tween_callback(_swell.bind(bar))
	var fill: MethodTweener = tween.tween_method(_show.bind(bar), from, value, FILL_TIME)
	fill.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _show(value: float, bar: String) -> void:
	if bar == FAMINE:
		famine.value = value
	elif bar == DENUNCIATION:
		denunciation.value = value
	else:
		quota.show_value(value)


func _swell(bar: String) -> void:
	var moved: Control = quota
	if bar == FAMINE:
		moved = famine
	elif bar == DENUNCIATION:
		moved = denunciation
	UiMotion.pulse(moved.get_parent() as Control)


## The Quota bar under its label.
func _quota_box() -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.theme_type_variation = CommonsTheme.EYEBROW
	label.text = tr("keyword.quota.name").to_upper()
	label.add_theme_color_override("font_color", PAPER)
	quota.setup(QUOTA_BAR, SEAL_WIDTH, 20)
	box.add_child(label)
	box.add_child(quota)
	return box


func _meter(key: String, bar: ProgressBar, color: Color, icon: Texture2D) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_child(_icon(icon))
	var label: Label = Label.new()
	label.theme_type_variation = CommonsTheme.EYEBROW
	label.text = tr(key).to_upper()
	label.add_theme_color_override("font_color", PAPER)
	bar.custom_minimum_size = METER_BAR
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	var ground: StyleBoxFlat = StyleBoxFlat.new()
	ground.bg_color = Color("4a4239")
	bar.add_theme_stylebox_override("background", ground)
	bar.max_value = 100
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(label)
	box.add_child(bar)
	return box


static func _icon(texture: Texture2D) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

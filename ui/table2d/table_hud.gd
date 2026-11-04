class_name TableHud
extends PanelContainer
## The bar across the top of the table: where you are in the run, both meters and your
## coupons. It reads a copy of the run state and never changes it.

const INK: Color = Color("1e1a16")
const PAPER: Color = Color("efe3c8")
const GRAIN: Color = Color("c8952b")
const ZEAL: Color = Color("c8341e")
const COUPON: Color = Color("6f9a62")

var status: Label = Label.new()
var coupons: Label = Label.new()
var famine: ProgressBar = ProgressBar.new()
var denunciation: ProgressBar = ProgressBar.new()


func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = INK
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	status.add_theme_color_override("font_color", PAPER)
	status.add_theme_font_size_override("font_size", 26)
	status.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	row.add_child(_meter("meter.famine", famine, GRAIN, ScreenKit.ART.icon_famine))
	row.add_child(_meter("meter.denunciation", denunciation, ZEAL, ScreenKit.ART.icon_denunciation))
	row.add_child(_icon(ScreenKit.ART.icon_coupon))
	coupons.add_theme_color_override("font_color", COUPON)
	coupons.add_theme_font_size_override("font_size", 26)
	coupons.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	row.add_child(coupons)
	add_child(row)


func show_state(state: RunState, target: float, rounds: int) -> void:
	status.text = (
		tr("table.status")
		. format(
			{
				"year": state.year,
				"set": tr("set.type.%d" % state.set_type),
				"round": mini(state.round_index + 1, rounds),
				"rounds": rounds,
				"progress": Strings.score(state.set_progress),
				"target": Strings.score(target),
			}
		)
	)
	coupons.text = tr("table.coupons").format({"count": state.coupons})
	famine.value = state.famine
	denunciation.value = state.denunciation


func _meter(key: String, bar: ProgressBar, color: Color, icon: Texture2D) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_child(_icon(icon))
	var label: Label = Label.new()
	label.theme_type_variation = CommonsTheme.EYEBROW
	label.text = tr(key).to_upper()
	label.add_theme_color_override("font_color", PAPER)
	bar.custom_minimum_size = Vector2(180, 18)
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

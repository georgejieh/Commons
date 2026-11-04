class_name TableBanner
extends PanelContainer
## A paper banner for the table's big moments: who takes the landlord seat, a bomb, who
## wins the round. It stamps in, holds, and fades. One banner is made with the table and
## reused, so a round instances nothing.

var _text: Label = Label.new()
var _tween: Tween = null


func _ready() -> void:
	theme_type_variation = CommonsTheme.SHEET
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.theme_type_variation = CommonsTheme.TITLE
	_text.add_theme_font_size_override("font_size", 46)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_text)
	modulate.a = 0.0


## Hides the banner at once, for a new deal.
func dismiss() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0


## Shows text, in color, for the preset hold time.
func announce(text: String, color: Color) -> void:
	_text.text = text
	_text.add_theme_color_override("font_color", color)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	UiMotion.stamp(self)
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(UiMotion.seconds(UiMotion.PRESETS.banner_hold))
	_tween.tween_property(self, "modulate:a", 0.0, UiMotion.seconds(0.3))

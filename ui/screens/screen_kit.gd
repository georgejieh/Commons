class_name ScreenKit
extends RefCounted
## Builds the poster-style pieces every simple screen uses, so screens stay small.

const PAPER: Color = Color("efe3c8")
const CARD: Color = Color("f6edd9")
const INK: Color = Color("1e1a16")
const RED: Color = Color("9e1b16")
const GOLD: Color = Color("f3d98a")
const COUPON: Color = Color("6f9a62")


## A full-screen paper page holding a centered column.
static func page(root: Control) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ground: ColorRect = ColorRect.new()
	ground.color = PAPER
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ground)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 96)
	root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	return column


static func label(text: String, font_size: int, color: Color = INK) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made


static func button(text: String, color: Color = INK) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(320, 64)
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	made.add_theme_font_size_override("font_size", 26)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	made.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	made.add_theme_stylebox_override("hover", hover)
	made.add_theme_stylebox_override("focus", hover)
	made.add_theme_color_override("font_color", Color("fbf6ea"))
	return made


## A paper card with a border, holding a column.
static func card(min_size: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = min_size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_border_width_all(3)
	style.border_color = INK
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


## The card's outer panel, for adding it to a row.
static func card_panel(column: VBoxContainer) -> Control:
	return column.get_parent() as Control

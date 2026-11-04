class_name ScreenKit
extends RefCounted
## Builds the poster-style pieces every simple screen uses, so screens stay small.

const PAPER: Color = Color("efe3c8")
const CARD: Color = Color("f6edd9")
const INK: Color = Color("1e1a16")
const RED: Color = Color("9e1b16")
const GOLD: Color = Color("f3d98a")
const COUPON: Color = Color("6f9a62")
const ART: ArtLibrary = preload("res://data/ui/art.tres")
## How wide the paper halo around text is, in pixels.
const HALO_SIZE: int = 10
## Pixels of the card stock's border that never stretch.
const PAPER_BORDER: float = 26.0
## How far the backdrop darkens under the content, so text on art stays readable.
const SHADE: Color = Color(0.08, 0.06, 0.04, 0.35)


## A full-screen page over a backdrop, or over paper when there is none, holding a
## column.
static func page(root: Control, backdrop: Texture2D = null) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover(backdrop if backdrop != null else ART.paper))
	if backdrop != null:
		root.theme = halo_theme()
		var shade: ColorRect = ColorRect.new()
		shade.color = SHADE
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
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


## Gives every label a paper-colored halo, so ink text reads over busy art.
static func halo_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.set_constant("outline_size", "Label", HALO_SIZE)
	theme.set_color("font_outline_color", "Label", PAPER)
	return theme


## A texture that fills its parent, cropped to keep its shape.
static func cover(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Aged card stock with its ink border kept at the edges, for panels and cards.
static func paper_style(margin: int = 18) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = ART.panel_paper
	style.set_texture_margin_all(PAPER_BORDER)
	style.set_content_margin_all(margin)
	return style


## A paper card with a border, holding a column.
static func card(min_size: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", paper_style())
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


## The card's outer panel, for adding it to a row.
static func card_panel(column: VBoxContainer) -> Control:
	return column.get_parent() as Control

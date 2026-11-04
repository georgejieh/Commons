class_name CommonsTheme
extends RefCounted
## Builds the demo's component theme from UiStyle tokens: tactile buttons in four kinds,
## a gold focus ring, paper sheets, meters, form controls and a type scale. Screens pick
## a kind with theme_type_variation; nothing styles itself by hand.

const STYLE: UiStyle = preload("res://data/ui/ui_style.tres")
const MEDIUM: FontVariation = preload("res://ui/theme/oswald_medium.tres")
const BOLD: FontVariation = preload("res://ui/theme/oswald_bold.tres")
const PANEL_PAPER: Texture2D = preload("res://art/ui/panel_paper.png")
## Button kinds: [variation name, face, bottom edge, text color].
const PRIMARY: String = "PrimaryButton"
const SECONDARY: String = "Button"
const COUPON: String = "CouponButton"
const GHOST: String = "GhostButton"
const HEADLINE: String = "Headline"
const TITLE: String = "Title"
const EYEBROW: String = "Eyebrow"
const CAPTION: String = "Caption"
const SHEET: String = "Sheet"
## The card stock's border, in texture pixels, that a sheet never stretches.
const SHEET_BORDER: float = 26.0
## How much a hovered face lightens, and a disabled one fades.
const HOVER_LIGHTEN: float = 0.1
const DISABLED_ALPHA: float = 0.45


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = MEDIUM
	theme.default_font_size = STYLE.body_size
	_buttons(theme)
	_labels(theme)
	_sheet(theme)
	_controls(theme)
	return theme


static func _buttons(theme: Theme) -> void:
	var kinds: Array[Array] = [
		[SECONDARY, STYLE.ink_soft, STYLE.ink, STYLE.paper_bright],
		[PRIMARY, STYLE.vermilion, STYLE.vermilion_dark, STYLE.paper_bright],
		[COUPON, STYLE.ration_green, STYLE.ration_green_dark, STYLE.paper_bright],
		[GHOST, Color(STYLE.paper_bright, 0.9), STYLE.ink_soft, STYLE.ink],
	]
	for kind: Array in kinds:
		var name: String = kind[0]
		var face: Color = kind[1]
		var edge: Color = kind[2]
		var text: Color = kind[3]
		if name != SECONDARY:
			theme.set_type_variation(name, "Button")
		theme.set_stylebox("normal", name, _key(face, edge, STYLE.shadow_drop))
		theme.set_stylebox(
			"hover", name, _key(face.lightened(HOVER_LIGHTEN), edge, STYLE.shadow_drop)
		)
		theme.set_stylebox("pressed", name, _key(face.darkened(0.08), edge, STYLE.pressed_drop))
		theme.set_stylebox("hover_pressed", name, _key(face, edge, STYLE.pressed_drop))
		var off: StyleBoxFlat = _key(Color(STYLE.paper_bright, 0.35), Color(edge, 0.5), 2)
		off.shadow_size = 0
		theme.set_stylebox("disabled", name, off)
		theme.set_stylebox("focus", name, _focus_ring())
		theme.set_font("font", name, BOLD)
		theme.set_font_size("font_size", name, STYLE.button_size)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			theme.set_color(state, name, text)
		theme.set_color("font_hover_pressed_color", name, text)
		theme.set_color("font_focus_color", name, text)
		theme.set_color("font_disabled_color", name, Color(STYLE.ink, DISABLED_ALPHA))


## A raised key: a flat face over a thicker bottom edge that shrinks when pressed, so the
## label sinks with it.
static func _key(face: Color, edge: Color, drop: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = edge
	box.set_border_width_all(STYLE.border)
	box.border_width_bottom = STYLE.border + drop
	box.set_corner_radius_all(STYLE.radius)
	box.content_margin_left = STYLE.pad_x
	box.content_margin_right = STYLE.pad_x
	box.content_margin_top = STYLE.pad_y + (STYLE.shadow_drop - drop)
	box.content_margin_bottom = STYLE.pad_y
	box.shadow_color = STYLE.shadow
	box.shadow_size = 4 if drop > STYLE.pressed_drop else 1
	box.shadow_offset = Vector2(0, 3 if drop > STYLE.pressed_drop else 1)
	box.anti_aliasing = true
	return box


static func _focus_ring() -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = STYLE.gold
	ring.set_border_width_all(STYLE.focus_width)
	ring.set_corner_radius_all(STYLE.radius + STYLE.focus_gap)
	ring.set_expand_margin_all(STYLE.focus_gap)
	return ring


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", STYLE.ink)
	var levels: Array[Array] = [
		[HEADLINE, BOLD, STYLE.headline_size, STYLE.vermilion],
		[TITLE, BOLD, STYLE.title_size, STYLE.ink],
		[EYEBROW, _tracked(), STYLE.eyebrow_size, STYLE.ink_soft],
		[CAPTION, MEDIUM, STYLE.caption_size, STYLE.ink_soft],
	]
	for level: Array in levels:
		var name: String = level[0]
		theme.set_type_variation(name, "Label")
		theme.set_font("font", name, level[1])
		theme.set_font_size("font_size", name, level[2])
		theme.set_color("font_color", name, level[3])


## The medium face with wide letter spacing, for small uppercase labels.
static func _tracked() -> FontVariation:
	var tracked: FontVariation = MEDIUM.duplicate()
	tracked.spacing_glyph = STYLE.eyebrow_tracking
	return tracked


static func _sheet(theme: Theme) -> void:
	theme.set_type_variation(SHEET, "PanelContainer")
	var paper: StyleBoxTexture = StyleBoxTexture.new()
	paper.texture = PANEL_PAPER
	paper.set_texture_margin_all(SHEET_BORDER)
	paper.set_content_margin_all(STYLE.gap + 6)
	theme.set_stylebox("panel", SHEET, paper)
	theme.set_stylebox("panel", "TooltipPanel", paper)
	theme.set_color("font_color", "TooltipLabel", STYLE.ink)


static func _controls(theme: Theme) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(STYLE.ink, 0.6)
	track.border_color = STYLE.ink
	track.set_border_width_all(1)
	track.set_corner_radius_all(STYLE.radius)
	theme.set_stylebox("background", "ProgressBar", track)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = STYLE.gold
	fill.set_corner_radius_all(STYLE.radius)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_stylebox("slider", "HSlider", track)
	var grabbed: StyleBoxFlat = fill.duplicate()
	grabbed.bg_color = STYLE.vermilion
	theme.set_stylebox("grabber_area", "HSlider", grabbed)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabbed)
	theme.set_stylebox("focus", "HSlider", _focus_ring())
	theme.set_stylebox("focus", "CheckBox", _focus_ring())
	theme.set_color("font_color", "CheckBox", STYLE.ink)
	theme.set_color("font_hover_color", "CheckBox", STYLE.vermilion)
	theme.set_color("font_pressed_color", "CheckBox", STYLE.ink)
	theme.set_font_size("font_size", "CheckBox", STYLE.body_size + 4)
	var field: StyleBoxFlat = StyleBoxFlat.new()
	field.bg_color = STYLE.paper_bright
	field.border_color = STYLE.ink
	field.set_border_width_all(STYLE.border)
	field.set_corner_radius_all(STYLE.radius)
	field.set_content_margin_all(8)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _focus_ring())
	theme.set_color("font_color", "LineEdit", STYLE.ink)

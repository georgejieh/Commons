class_name CommonsTheme
extends RefCounted
## Builds the demo's component theme from UiStyle tokens: ticket buttons in four kinds,
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
const HOVER_LIGHTEN: float = 0.12
const PRESS_DARKEN: float = 0.15
## Pixel sizes of the drawn slider knob and check box.
const KNOB: int = 26
const BOX: int = 26
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
		[SECONDARY, STYLE.ticket_kraft, STYLE.paper_bright],
		[PRIMARY, STYLE.ticket_red, STYLE.paper_bright],
		[COUPON, STYLE.ticket_green, STYLE.paper_bright],
		[GHOST, Color.WHITE, STYLE.ink],
	]
	for kind: Array in kinds:
		var name: String = kind[0]
		var ink: Color = kind[1]
		var text: Color = kind[2]
		if name != SECONDARY:
			theme.set_type_variation(name, "Button")
		theme.set_stylebox("normal", name, _ticket(ink, false))
		theme.set_stylebox("hover", name, _ticket(ink.lightened(HOVER_LIGHTEN), false))
		theme.set_stylebox("pressed", name, _ticket(ink.darkened(PRESS_DARKEN), true))
		theme.set_stylebox("hover_pressed", name, _ticket(ink.darkened(PRESS_DARKEN), true))
		theme.set_stylebox("disabled", name, _ticket(Color(ink, DISABLED_ALPHA), false))
		theme.set_stylebox("focus", name, _focus_ring())
		theme.set_font("font", name, BOLD)
		theme.set_font_size("font_size", name, STYLE.button_size)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			theme.set_color(state, name, text)
		theme.set_color("font_hover_pressed_color", name, text)
		theme.set_color("font_focus_color", name, text)
		theme.set_color("font_disabled_color", name, Color(text, DISABLED_ALPHA + 0.2))


## A printed ticket: the panels' own card stock with its ruled border, dyed with the
## kind's ink. A pressed ticket sits lower, so the label sinks with it.
static func _ticket(ink: Color, pressed: bool) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = PANEL_PAPER
	box.set_texture_margin_all(SHEET_BORDER)
	box.modulate_color = ink
	var sink: int = STYLE.shadow_drop - STYLE.pressed_drop if pressed else 0
	box.content_margin_left = STYLE.pad_x
	box.content_margin_right = STYLE.pad_x
	box.content_margin_top = STYLE.pad_y + sink
	box.content_margin_bottom = STYLE.pad_y - sink
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
	var rail: StyleBoxFlat = track.duplicate()
	rail.content_margin_top = 4
	rail.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", rail)
	var grabbed: StyleBoxFlat = fill.duplicate()
	grabbed.bg_color = STYLE.vermilion
	theme.set_stylebox("grabber_area", "HSlider", grabbed)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabbed)
	var knob: ImageTexture = _seal(STYLE.vermilion)
	theme.set_icon("grabber", "HSlider", knob)
	theme.set_icon("grabber_highlight", "HSlider", _seal(STYLE.vermilion.lightened(0.15)))
	theme.set_icon("grabber_disabled", "HSlider", _seal(STYLE.ink_soft))
	theme.set_icon("unchecked", "CheckBox", _check_box(false))
	theme.set_icon("checked", "CheckBox", _check_box(true))
	theme.set_constant("h_separation", "CheckBox", 12)
	theme.set_stylebox("focus", "HSlider", _focus_ring())
	theme.set_stylebox("focus", "CheckBox", _focus_ring())
	# CheckBox inherits Button's look; it reads as a plain line of text with a box.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var plain: StyleBoxEmpty = StyleBoxEmpty.new()
		plain.content_margin_top = 4
		plain.content_margin_bottom = 4
		theme.set_stylebox(state, "CheckBox", plain)
	theme.set_color("font_focus_color", "CheckBox", STYLE.ink)
	theme.set_color("font_hover_pressed_color", "CheckBox", STYLE.vermilion)
	theme.set_font("font", "CheckBox", MEDIUM)
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


## A round ink seal with a paper rim, for the slider's knob.
static func _seal(ink: Color) -> ImageTexture:
	var image: Image = Image.create(KNOB, KNOB, false, Image.FORMAT_RGBA8)
	var middle: Vector2 = Vector2(KNOB, KNOB) / 2.0
	for y: int in KNOB:
		for x: int in KNOB:
			var far: float = (Vector2(x + 0.5, y + 0.5) - middle).length()
			var color: Color = Color(0, 0, 0, 0)
			if far < KNOB / 2.0 - 4.0:
				color = ink
			elif far < KNOB / 2.0 - 2.0:
				color = STYLE.paper_bright
			elif far < KNOB / 2.0:
				color = STYLE.ink
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## An inked box on paper; checked, it is filled with a vermilion stamp.
static func _check_box(checked: bool) -> ImageTexture:
	var image: Image = Image.create(BOX, BOX, false, Image.FORMAT_RGBA8)
	for y: int in BOX:
		for x: int in BOX:
			var edge: int = mini(mini(x, y), mini(BOX - 1 - x, BOX - 1 - y))
			var color: Color = STYLE.paper_bright
			if edge < 3:
				color = STYLE.ink
			elif checked and edge >= 6:
				color = STYLE.vermilion
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

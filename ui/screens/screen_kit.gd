class_name ScreenKit
extends RefCounted
## Builds the pieces every simple screen uses from the component theme: a page over art
## or paper, an eyebrow-and-headline header, buttons by kind, paper sheets, stat tiles
## and a footer bar. Screens compose these and call reveal() so they arrive in motion.

const ART: ArtLibrary = preload("res://data/ui/art.tres")
const STYLE: UiStyle = preload("res://data/ui/ui_style.tres")
## The bold poster face for titles; everything else uses the theme's medium weight.
const DISPLAY_BOLD: FontVariation = preload("res://ui/theme/oswald_bold.tres")
## A typewriter face for the ledger's tallies.
const TYPEWRITER: FontFile = preload("res://art/fonts/CourierPrime-Regular.ttf")
const TYPEWRITER_BOLD: FontFile = preload("res://art/fonts/CourierPrime-Bold.ttf")
const PAPER: Color = Color("efe3c8")
const INK: Color = Color("1e1a16")
const RED: Color = Color("b02a17")
const GOLD: Color = Color("e0b84a")
const COUPON: Color = Color("3f6338")
## How far the backdrop darkens under the content, so text on art stays readable.
const SHADE: Color = Color(0.08, 0.06, 0.04, 0.3)
## How wide the paper halo around text on art is, in pixels.
const HALO_SIZE: int = 10
## Page margins and the widest a content column grows.
const PAGE_MARGIN: int = 88
const MIN_BUTTON_WIDTH: int = 260


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
		margin.add_theme_constant_override("margin_" + side, PAGE_MARGIN)
	root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", STYLE.gap + 8)
	margin.add_child(column)
	return column


## A small tracked label over a big headline, the way a poster leads.
static func header(eyebrow_text: String, headline_text: String, color: Color = RED) -> Control:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.add_child(eyebrow(eyebrow_text))
	var headline: Label = styled(headline_text, CommonsTheme.HEADLINE)
	headline.add_theme_color_override("font_color", color)
	block.add_child(headline)
	return block


static func eyebrow(text: String) -> Label:
	return styled(text.to_upper(), CommonsTheme.EYEBROW)


## A label in one of the theme's type levels.
static func styled(text: String, level: String) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.theme_type_variation = level
	# Headlines and eyebrows keep to one line; a wrapping label in a row shrinks to nothing.
	var one_line: bool = level == CommonsTheme.HEADLINE or level == CommonsTheme.EYEBROW
	made.autowrap_mode = TextServer.AUTOWRAP_OFF if one_line else TextServer.AUTOWRAP_WORD_SMART
	return made


static func label(text: String, font_size: int, color: Color = INK) -> Label:
	var made: Label = Label.new()
	made.text = text
	if font_size >= STYLE.title_size:
		made.add_theme_font_override("font", DISPLAY_BOLD)
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made


## A button of one kind (CommonsTheme.PRIMARY, SECONDARY, COUPON or GHOST) that lifts
## on hover and sinks when pressed.
static func button(text: String, kind: String = CommonsTheme.SECONDARY) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.theme_type_variation = kind
	made.custom_minimum_size = Vector2(MIN_BUTTON_WIDTH, 0)
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiMotion.hoverable(made)
	return made


## A row of controls with the theme's gap.
static func row(children: Array[Control], separation: int = STYLE.gap) -> HBoxContainer:
	var made: HBoxContainer = HBoxContainer.new()
	made.add_theme_constant_override("separation", separation)
	for child: Control in children:
		made.add_child(child)
	return made


## Gives every label a paper-colored halo, so ink text reads over busy art.
static func halo_theme() -> Theme:
	var theme: Theme = Theme.new()
	for type: String in ["Label", CommonsTheme.EYEBROW, CommonsTheme.HEADLINE]:
		theme.set_constant("outline_size", type, HALO_SIZE)
		theme.set_color("font_outline_color", type, PAPER)
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


## Aged card stock with its ink border kept at the edges, for panels drawn by hand.
static func paper_style(margin: int = 18) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = ART.panel_paper
	style.set_texture_margin_all(CommonsTheme.SHEET_BORDER)
	style.set_content_margin_all(margin)
	return style


## A paper sheet holding a column.
static func card(min_size: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = CommonsTheme.SHEET
	panel.custom_minimum_size = min_size
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


## The card's outer panel, for adding it to a row.
static func card_panel(column: VBoxContainer) -> Control:
	return column.get_parent() as Control


## A stat tile: a tracked caption over a big number that rolls up from from_value.
static func stat(caption: String, value: float, from_value: float = 0.0) -> Control:
	var tile: VBoxContainer = card(Vector2(240, 0))
	tile.add_child(eyebrow(caption))
	var number: Label = styled("", CommonsTheme.TITLE)
	tile.add_child(number)
	UiMotion.count(
		number, from_value, value, func(shown: float) -> String: return Strings.score(shown)
	)
	return card_panel(tile)


## Brings a page's pieces in one after another.
static func reveal(column: VBoxContainer) -> void:
	var pieces: Array[Control] = []
	for child: Node in column.get_children():
		var piece: Control = child as Control
		if piece != null:
			pieces.append(piece)
	UiMotion.enter(pieces)

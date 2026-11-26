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
## On a page that would overflow at a larger text size, the margin and the gaps between
## its rows give way first, to this margin and this share of each gap (ADR 0034).
const LEAST_PAGE_MARGIN: int = 24
const LEAST_GAP_SHARE: float = 0.5
const FULL_GAP: StringName = &"full_gap"
const MIN_BUTTON_WIDTH: int = 260
## Space kept around a face in a portrait box, as a share of the head's size per side.
const FACE_MARGIN: float = 0.12


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
	var make_room: Callable = give_way.bind(root, margin, column)
	root.resized.connect(make_room)
	column.minimum_size_changed.connect(make_room)
	return column


## Shrinks a page's margin, then the gaps between its rows, as far as it must for what
## is on it to fit the screen, and no further than LEAST_PAGE_MARGIN and LEAST_GAP_SHARE.
## A page that fits keeps its full margin and gaps.
static func give_way(root: Control, margin: MarginContainer, column: VBoxContainer) -> void:
	if root.size.x <= 0.0 or root.size.y <= 0.0:
		return
	if not column.has_meta(FULL_GAP):
		column.set_meta(FULL_GAP, column.get_theme_constant("separation"))
	var full_gap: int = column.get_meta(FULL_GAP)
	var gaps: int = maxi(_shown_rows(column) - 1, 0)
	var shown_gap: int = column.get_theme_constant("separation")
	var need: Vector2 = column.get_combined_minimum_size()
	var content_tall: float = need.y - shown_gap * gaps
	var side: int = _room(root.size.x - need.x)
	var top: int = _room(root.size.y - content_tall - full_gap * gaps)
	var gap: int = full_gap
	if gaps > 0 and top == LEAST_PAGE_MARGIN:
		var spare: float = (root.size.y - content_tall - LEAST_PAGE_MARGIN * 2.0) / gaps
		var least_gap: int = ceili(full_gap * LEAST_GAP_SHARE)
		gap = clampi(floori(spare), least_gap, full_gap)
	_set_constant(margin, "margin_left", side)
	_set_constant(margin, "margin_right", side)
	_set_constant(margin, "margin_top", top)
	_set_constant(margin, "margin_bottom", top)
	_set_constant(column, "separation", gap)


## The margin a side keeps with spare room left over at the full margin.
static func _room(spare: float) -> int:
	return clampi(floori(spare / 2.0), LEAST_PAGE_MARGIN, PAGE_MARGIN)


static func _shown_rows(column: VBoxContainer) -> int:
	var rows: int = 0
	for child: Node in column.get_children():
		if child is Control and (child as Control).visible:
			rows += 1
	return rows


## Sets a constant only when it changes, so a layout that settles stays settled.
static func _set_constant(control: Control, constant: String, value: int) -> void:
	if control.get_theme_constant(constant) != value:
		control.add_theme_constant_override(constant, value)


## A full-screen page over a backdrop with its content centered on one sheet, for
## verdicts and summaries.
static func centered_sheet(root: Control, backdrop: Texture2D) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover(backdrop))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var sheet: VBoxContainer = card(Vector2(1040, 0))
	sheet.add_theme_constant_override("separation", STYLE.gap + 10)
	center.add_child(card_panel(sheet))
	return sheet


## A full-screen page over a backdrop with its content on one sheet down the left side,
## so the art shows beside it and nothing hangs over the art's own paper. A sheet with
## more on it than the page is tall is drawn smaller, so its last button is never off
## the screen.
static func side_sheet(root: Control, backdrop: Texture2D, width: float) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover(backdrop))
	var shade: ColorRect = ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var sheet: VBoxContainer = card(Vector2(width, 0))
	sheet.add_theme_constant_override("separation", STYLE.gap + 8)
	var panel: Control = card_panel(sheet)
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = PAGE_MARGIN
	panel.offset_top = PAGE_MARGIN / 2.0
	panel.offset_bottom = -PAGE_MARGIN / 2.0
	panel.offset_right = PAGE_MARGIN + width
	var fit: Callable = fit_side_sheet.bind(root, panel)
	panel.minimum_size_changed.connect(fit)
	panel.resized.connect(fit)
	root.resized.connect(fit)
	return sheet


## Draws a side sheet smaller, from its top left corner, when what is on it is taller
## than the page between its margins.
static func fit_side_sheet(root: Control, panel: Control) -> void:
	var room: float = root.size.y - PAGE_MARGIN
	var tall: float = panel.get_combined_minimum_size().y
	var fit: float = 1.0 if tall <= room or room <= 0.0 else room / tall
	panel.pivot_offset = Vector2.ZERO
	panel.scale = Vector2(fit, fit)


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


## A label of the given Standard size, set at the chosen text size.
static func label(text: String, font_size: int, color: Color = INK) -> Label:
	var made: Label = Label.new()
	made.text = text
	if font_size >= STYLE.title_size:
		made.add_theme_font_override("font", DISPLAY_BOLD)
	made.add_theme_font_size_override("font_size", TextSize.px(font_size))
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


## Takes the backdrop's paper halo off text that stands on a paper sheet, where it is ink
## on paper and a halo only softens it. Set as the sheet's theme.
static func ink_theme() -> Theme:
	var theme: Theme = Theme.new()
	for type: String in ["Label", CommonsTheme.EYEBROW, CommonsTheme.HEADLINE, CommonsTheme.TITLE]:
		theme.set_constant("outline_size", type, 0)
	return theme


## A texture that fills its parent, cropped to keep its shape.
static func cover(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ArtStages.resolve(texture)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Aged card stock with its ink border kept at the edges, for panels drawn by hand.
static func paper_style(margin: int = 18) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = ArtStages.resolve(ART.panel_paper)
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


## A stat tile for one of the run's figures (ShownFigures names them), as ShownFigures
## shows it: the rolling number, or its words ("None reported", ample, fulfilled).
static func figure_stat(caption: String, state: RunView, figure: String, value: float) -> Control:
	var words: String = ShownFigures.tile_text(state, figure)
	if words.is_empty():
		return stat(caption, value)
	var tile: VBoxContainer = card(Vector2(240, 0))
	tile.add_child(eyebrow(caption))
	tile.add_child(styled(words, CommonsTheme.TITLE))
	return card_panel(tile)


## Brings a page's pieces in one after another.
static func reveal(column: VBoxContainer) -> void:
	var pieces: Array[Control] = []
	for child: Node in column.get_children():
		var piece: Control = child as Control
		if piece != null:
			pieces.append(piece)
	UiMotion.enter(pieces)


## A paper-colored edge around text that sits straight on the table, so it stays
## readable however dark the room behind it gets.
static func paper_outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", STYLE.paper)
	label.add_theme_constant_override("outline_size", 8)


## A portrait cropped to a box of aspect (width / height), centered on the face.
static func face_crop(picture: Texture2D, face: Rect2, aspect: float) -> Texture2D:
	var crop: AtlasTexture = AtlasTexture.new()
	crop.atlas = picture
	crop.region = face_region(picture.get_size(), face, aspect)
	return crop


## The pixel region of an image of size that shows the whole face (fractions of the
## image) with a margin, at the given aspect, centered on the face and kept inside the
## image.
static func face_region(size: Vector2, face: Rect2, aspect: float) -> Rect2:
	var head: Rect2 = Rect2(face.position * size, face.size * size)
	var want: Vector2 = head.size * (1.0 + 2.0 * FACE_MARGIN)
	if want.x / want.y < aspect:
		want.x = want.y * aspect
	else:
		want.y = want.x / aspect
	var fit: float = minf(1.0, minf(size.x / want.x, size.y / want.y))
	want *= fit
	var corner: Vector2 = head.get_center() - want / 2.0
	corner = corner.clamp(Vector2.ZERO, size - want)
	return Rect2(corner, want)


## A Cadre's art for the current corruption stage.
static func cadre_art(cadre_id: String) -> Texture2D:
	return ArtStages.picture(ART.cadre_path(cadre_id))


## An ending's picture for the current corruption stage, or null while it has none.
static func ending_art(ending_id: String) -> Texture2D:
	return ArtStages.picture(ART.ending_path(ending_id))


## A modifier's rules, saying so when a Cadre also pays on your teammate's plays.
static func rule_text(controller: RunController, modifier_id: String) -> String:
	var rule: String = controller.texts.modifier_text(modifier_id)
	if controller.items.counts_for_teammate(modifier_id):
		rule += " " + TranslationServer.translate("modifier.counts_for_teammate")
	# A held Cadre with run state says where it stands (ADR 0021).
	var standing: String = controller.items.cadre_standing(modifier_id).line
	if not standing.is_empty():
		rule += " " + standing
	return rule


## A Cadre's name over its rules, wrapped for a plain tooltip.
static func cadre_tip(controller: RunController, cadre_id: String) -> String:
	var name: String = TranslationServer.translate("modifier.%s.name" % cadre_id)
	return "%s\n%s" % [name, Keywords.wrapped(rule_text(controller, cadre_id))]

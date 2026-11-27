class_name ScreenKit
extends RefCounted
## Builds the pieces every simple screen uses from the component theme: a page over art
## or paper, an eyebrow-and-headline header, buttons by kind, paper sheets, stat tiles
## and a footer bar. Screens compose these and call reveal() so they arrive in motion.

## The art every page draws its backdrops, paper and pictures from.
const ART: ArtLibrary = preload("res://data/ui/art.tres")
## The design tokens the inks, gaps and sizes below are read from.
const STYLE: UiStyle = preload("res://data/ui/ui_style.tres")
## The bold poster face for titles; everything else uses the theme's medium weight.
const DISPLAY_BOLD: FontVariation = preload("res://ui/theme/oswald_bold.tres")
## A typewriter face for the ledger's tallies.
const TYPEWRITER: FontFile = preload("res://art/fonts/CourierPrime-Regular.ttf")
## The bold typewriter face, for a ledger's titles and bold lines.
const TYPEWRITER_BOLD: FontFile = preload("res://art/fonts/CourierPrime-Bold.ttf")
## The card stock panels and cards are made of. The inks from here on are every screen's, each
## defined once in the style data: a file reads these names and keeps no colour of its own.
const PAPER: Color = STYLE.paper
## The black of print and outlines.
const INK: Color = STYLE.ink
## The red of a signal: a stamp, a refusal, the main action.
const RED: Color = STYLE.vermilion
## The gold of a signal: this is the thing.
const GOLD: Color = STYLE.gold
## The green of coupons, and of what pays them, on paper.
const COUPON: Color = STYLE.coupon
## The lighter green of coupons shown over the dark table.
const COUPON_ON_DARK: Color = STYLE.coupon_on_dark
## The deep red of a seal's ink: a landlord's mark, a lie caught, a total.
const SEAL: Color = STYLE.seal
## The faded ink of a loss counted on the table.
const LOSS: Color = STYLE.loss
## The quiet brown of what is settled or waiting, such as a cleared audit.
const QUIET: Color = STYLE.quiet
## The near-black printed on tickets, chips and the surname's slip.
const TICKET_INK: Color = STYLE.ticket_ink
## The red of a picked ticket and of a printed band.
const PICKED: Color = STYLE.picked
## The brass ring around a ticket or paper that has the focus.
const FOCUS_RING: Color = STYLE.focus_ring
## The worn brown of a ticket's band, a locked ticket and a perforation.
const WORN_PRINT: Color = STYLE.worn_print
## The dark brown edge drawn around village paper.
const PAPER_EDGE: Color = STYLE.paper_edge
## The faint brown of a printed frame, a ledger's band and a keyword's soft words.
const FAINT_INK: Color = STYLE.faint_ink
## The brown line of a fold across paper.
const FOLD: Color = STYLE.fold
## The gold of a hint: a hinted card's edge and a usable Campaign's mark.
const HINT: Color = STYLE.hint
## The cream card stock a playing card is printed on.
const CARD_STOCK: Color = STYLE.card_stock
## The bright red printed on a wild card's ribbon and on a file's stamp.
const PRINT_RED: Color = STYLE.print_red
## The red of an ending's title and frame.
const ENDING_INK: Color = STYLE.ending_ink
## The older, darker paper of a portrait's mount and a notice posted on the wall.
const OLD_PAPER: Color = STYLE.old_paper
## The wheat ochre a Quota bar and the Famine meter fill with.
const GRAIN_BAR: Color = STYLE.grain_bar
## The empty ground of the table's top bar and the Quota bar.
const BAR_GROUND: Color = STYLE.bar_ground
## The warm gold of a met Quota's bar and of a callout's rays.
const GLOW: Color = STYLE.glow
## The first of the layers a page draws in over its own pieces, lowest first, as z_index: a
## piece being acted out lifts over its row.
const LAYER_LIFTED: int = 1
## A seal, a flying paper and the rank picker's question stand over every piece.
const LAYER_OVER: int = 2
## The shop's slip, which explains any of the pieces under it.
const LAYER_SLIP: int = 3
## An opened envelope, which covers the page and the slip.
const LAYER_ENVELOPE: int = 4
## The deck sheet, over the envelope whose deck card it places; a card dragged on the swap board.
const LAYER_SHEET: int = 5
## How far the backdrop darkens under the content, so text on art stays readable.
const SHADE: Color = Color(0.08, 0.06, 0.04, 0.3)
## Deeper, under a verdict or a summary centred on one sheet.
const VERDICT_SHADE: Color = Color(0.05, 0.03, 0.02, 0.55)
## How wide the paper halo around text on art is, in pixels.
const HALO_SIZE: int = 10
## Page margins and the widest a content column grows.
const PAGE_MARGIN: int = 88
## Where a page keeps the fit it connected to its root's resized, for clear_page.
const PAGE_FIT: StringName = &"page_fit"
## The least width, in pixels, of a button, so a short label still makes a ticket.
const MIN_BUTTON_WIDTH: int = 260


## A full-screen page over a backdrop, or over paper when there is none, holding a
## column. A backdrop is tinted by tint and darkened under the column by dim.
static func page(
	root: Control, backdrop: Texture2D = null, dim: Color = SHADE, tint: Color = Color.WHITE
) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var art: TextureRect = cover(backdrop if backdrop != null else ART.paper)
	art.modulate = tint
	root.add_child(art)
	if backdrop != null:
		root.theme = _halo_theme()
		root.add_child(shade(dim))
	var margin: MarginContainer = margins(PAGE_MARGIN, PAGE_MARGIN)
	root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", STYLE.gap + 8)
	margin.add_child(column)
	var make_room: Callable = PageFit.give_way.bind(root, margin, column)
	root.resized.connect(make_room)
	root.set_meta(PAGE_FIT, make_room)
	column.minimum_size_changed.connect(make_room)
	return column


## Frees every child of node, taken out of the tree at once so what is built in its place
## lays out without them.
static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Takes a page built on root down, with the fit it connected to root, so the page can
## be built on root again.
static func clear_page(root: Control) -> void:
	if root.has_meta(PAGE_FIT):
		var fit: Callable = root.get_meta(PAGE_FIT)
		if root.resized.is_connected(fit):
			root.resized.disconnect(fit)
		root.remove_meta(PAGE_FIT)
	clear(root)


## A full-screen page over a backdrop with its content centered on one sheet, for
## verdicts and summaries.
static func centered_sheet(root: Control, backdrop: Texture2D) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover(backdrop))
	root.add_child(shade(VERDICT_SHADE))
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
	root.add_child(shade(SHADE))
	var sheet: VBoxContainer = card(Vector2(width, 0))
	sheet.add_theme_constant_override("separation", STYLE.gap + 8)
	var panel: Control = card_panel(sheet)
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = PAGE_MARGIN
	panel.offset_top = PAGE_MARGIN / 2.0
	panel.offset_bottom = -PAGE_MARGIN / 2.0
	panel.offset_right = PAGE_MARGIN + width
	var fit: Callable = _fit_side_sheet.bind(root, panel)
	panel.minimum_size_changed.connect(fit)
	panel.resized.connect(fit)
	root.resized.connect(fit)
	root.set_meta(PAGE_FIT, fit)
	return sheet


## Draws a side sheet smaller, from its top left corner, when what is on it is taller
## than the page between its margins.
static func _fit_side_sheet(root: Control, panel: Control) -> void:
	var room: float = root.size.y - PAGE_MARGIN
	var tall: float = panel.get_combined_minimum_size().y
	var fit: float = 1.0 if tall <= room or room <= 0.0 else room / tall
	panel.pivot_offset = Vector2.ZERO
	panel.scale = Vector2(fit, fit)


## Takes a Cancel press (Escape, or B on a pad) on a page that is showing: true when the
## event was one, and it is then handled. Every page with a Back button goes back on it.
static func take_cancel(shown: Control, event: InputEvent) -> bool:
	if not shown.is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return false
	shown.get_viewport().set_input_as_handled()
	return true


## A small tracked label over a big headline, the way a poster leads.
static func header(eyebrow_text: String, headline_text: String, color: Color = RED) -> Control:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.add_child(eyebrow(eyebrow_text))
	var headline: Label = styled(headline_text, CommonsTheme.HEADLINE)
	headline.add_theme_color_override("font_color", color)
	block.add_child(headline)
	return block


## A one-line label in capitals in the eyebrow type level, for the small line above a heading.
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
static func _halo_theme() -> Theme:
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


## A dim of color over a page's backdrop, which takes no input.
static func shade(color: Color) -> ColorRect:
	var made: ColorRect = ColorRect.new()
	made.color = color
	made.set_anchors_preset(Control.PRESET_FULL_RECT)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A margin that fills a page: side at its left and right, top above and below.
static func margins(side: int, top: int) -> MarginContainer:
	var made: MarginContainer = MarginContainer.new()
	made.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right"]:
		made.add_theme_constant_override("margin_" + edge, side)
	for edge: String in ["top", "bottom"]:
		made.add_theme_constant_override("margin_" + edge, top)
	return made


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
static func paper_outline(outlined: Label) -> void:
	outlined.add_theme_color_override("font_outline_color", PAPER)
	outlined.add_theme_constant_override("outline_size", 8)


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

class_name ChoicePaper
extends Control
## One item in an open envelope (ADR 0021), as a readable paper and the main thing on the
## screen: a Directive as its typed document with each Rate it raises, a Campaign as its
## leaflet, a plot card as its face with its mark plainly on it. Under it, on a paper
## strip of its own, what a card's mark does, or why the item cannot be kept now, in dark
## ink; the item itself always stays at full strength. The item is the button: a click on
## it, or accept while it has the focus, keeps it. Pointed at, it lifts a little under a
## gilt frame (GiltFrame) and a Keep tag, and asks the envelope's screen to explain it.

## Hovered or focused: the screen should explain this item.
signal pointed(index: int)
signal kept(index: int)

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
## The item's place with up to three choices, and with four or more. Each is a little
## wider for its height than a Campaign's leaflet, the widest item, so a leaflet, a card
## and a document all stand the place's full height and line up.
const ITEM_FEW: Vector2 = Vector2(270, 340)
const ITEM_MANY: Vector2 = Vector2(238, 300)
const FEW: int = 3
## The caption strip's height under the item, and the gap between them.
const CAPTION_HEIGHT: float = 92.0
const GAP: float = 8.0
## Room over the item for it to lift into with its tag, so a pointed paper never leaves
## its own box; how far it lifts and grows, and how long that takes.
const LIFT_ROOM: float = 40.0
const LIFT: float = 12.0
const LIFT_SCALE: float = 1.04
const LIFT_TIME: float = 0.16
## The frame's stand-off from the item, its halo, and the Keep tag's side margins.
const FRAME_OFF: float = 5.0
const HALO_REACH: float = 10.0
const TAG_MARGIN: int = 12
const NAME_SIZE: int = 26
## A Directive's Rate lines, never under 16 px.
const LINE_SIZE: int = 16
const CAPTION_SIZE: int = 17
const CAPTION_PADDING: int = 20
## A Directive document's padding, clear of the paper's printed border (17 px), and the
## room that padding takes from its name.
const DOCUMENT_PADDING: int = 20
const DOCUMENT_INSET: float = 44.0
const DOCUMENT_NAME_LEAST: int = 18
## A refusal is dark red ink, a caption dark ink.
const REFUSED_INK: Color = Color("7a160d")

var index: int = -1
## The item's own button: no face, the size of the item, over it.
var keep: Button = Button.new()
## 0 at rest, 1 lifted under the pointer.
var lift: float = 0.0:
	set(value):
		lift = value
		_lifted.position = Vector2(0, LIFT_ROOM - LIFT * value)
		_lifted.scale = Vector2.ONE * (1.0 + (LIFT_SCALE - 1.0) * value)
		queue_redraw()
## What the screen's explanation shows: the item's name and its full rules.
var title: String = ""
var rule: String = ""
## The Directive's Rate lines, to tick when it is issued; empty for anything else.
var lines: Array[Label] = []
## The item drawn: a document, a leaflet or a card, for the seal and for tests.
var item: Control = null
## The item's place, set by setup().
var item_size: Vector2 = ITEM_FEW

var _caption: Label = ScreenKit.label("", CAPTION_SIZE)
var _strip: PanelContainer = PanelContainer.new()
var _holder: Control = Control.new()
var _place: CenterContainer = CenterContainer.new()
## What lifts: the item's place and its Keep tag.
var _lifted: Control = Control.new()
var _tag: Label = Label.new()
var _lifting: Tween = null
var _cursor: bool = false
var _takeable: bool = true


## The item's place for an envelope showing count items.
static func item_for(count: int) -> Vector2:
	return ITEM_FEW if count <= FEW else ITEM_MANY


## True when a paper in shelf's open envelope has a caption to print under it: what a
## card's mark does, or why an item cannot be kept. Then every paper keeps room for one.
static func needs_strips(shelf: EnvelopeShelf) -> bool:
	for index: int in shelf.count():
		var kind: int = shelf.kind(index)
		var plain: bool = (
			kind == EnvelopeShelf.KIND_DIRECTIVE or kind == EnvelopeShelf.KIND_CAMPAIGN
		)
		if not plain or not shelf.refusal_key(index).is_empty():
			return true
	return false


## The whole paper's size for an item's place: room to lift, the item and, with strips,
## its caption strip.
static func size_for(item: Vector2, strips: bool = true) -> Vector2:
	var under: float = GAP + CAPTION_HEIGHT if strips else 0.0
	return Vector2(item.x, LIFT_ROOM + item.y + under)


## Lays the paper out for its place in the row; strips keeps room under the item for a
## caption. Call before showing an item.
func setup(at: int, place: Vector2, strips: bool = true) -> void:
	index = at
	item_size = place
	var whole: Vector2 = size_for(place, strips)
	custom_minimum_size = whole
	size = whole
	pivot_offset = whole / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lifted.size = place
	_lifted.pivot_offset = place / 2.0
	_lifted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lifted)
	_place.custom_minimum_size = place
	_place.size = place
	_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lifted.add_child(_place)
	# Always in the tree, so it is freed with the paper; shown only where it has room.
	var strip: Control = _caption_strip(place.x)
	strip.position = Vector2(0, LIFT_ROOM + place.y + GAP)
	strip.size = Vector2(place.x, CAPTION_HEIGHT)
	strip.visible = strips
	add_child(strip)
	_make_tag()
	# The item is the button: it has no face of its own, only the pointer and the focus.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		keep.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	keep.position = Vector2(0, LIFT_ROOM)
	keep.size = place
	keep.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(keep)
	lift = 0.0
	keep.mouse_entered.connect(func() -> void: pointed.emit(index))
	keep.focus_entered.connect(func() -> void: pointed.emit(index))
	keep.pressed.connect(func() -> void: kept.emit(index))


## The Keep tag that hangs on a pointed item's top edge: it says what a click does.
func _make_tag() -> void:
	_tag.text = TranslationServer.translate("envelope.keep").to_upper()
	_tag.theme_type_variation = CommonsTheme.EYEBROW
	_tag.add_theme_color_override("font_color", ScreenKit.STYLE.paper_bright)
	var ground: StyleBoxFlat = StyleBoxFlat.new()
	ground.bg_color = ScreenKit.STYLE.vermilion
	ground.set_corner_radius_all(ScreenKit.STYLE.radius)
	ground.content_margin_left = TAG_MARGIN
	ground.content_margin_right = TAG_MARGIN
	_tag.add_theme_stylebox_override("normal", ground)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	_lifted.add_child(_tag)


## A Directive: its typed document, a name over one Rate line per hand type it raises,
## filling the item's place exactly as a leaflet or card does, its text from the top.
func show_directive(controller: RunController, directive_id: String) -> void:
	title = controller.texts.directive_name(directive_id)
	rule = controller.texts.directive_text(directive_id)
	var sheet: VBoxContainer = ScreenKit.card(item_size)
	sheet.add_theme_constant_override("separation", 2)
	sheet.alignment = BoxContainer.ALIGNMENT_BEGIN
	sheet.add_child(ScreenKit.eyebrow(tr(DirectiveSheet.EYEBROW)))
	var name: Label = ScreenKit.label(title, NAME_SIZE)
	name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_fit_one_line(name, item_size.x - DOCUMENT_INSET)
	sheet.add_child(name)
	sheet.add_child(HSeparator.new())
	for type: int in controller.items.directive_types(directive_id):
		var line: Label = ScreenKit.label(DirectiveSheet.rate_line(controller, type), LINE_SIZE)
		# The condensed face keeps each Rate line to two lines at 16 px in the small place.
		line.autowrap_mode = TextServer.AUTOWRAP_WORD
		line.add_theme_constant_override("line_spacing", -2)
		sheet.add_child(line)
		lines.append(line)
	item = ScreenKit.card_panel(sheet)
	item.add_theme_stylebox_override("panel", ScreenKit.paper_style(DOCUMENT_PADDING))
	item.custom_minimum_size = item_size
	item.clip_contents = true
	_place.add_child(item)
	# Measured where the theme reaches it, so the sizes are the ones it is drawn at.
	_fit_lines(sheet, name)


## The document is a place of a fixed size: its Rate lines grow with the text size only
## while the whole document still fits it (ADR 0034).
## When the lines at their Standard size still do not fit, the name is set smaller, down
## to the size it has at Standard.
func _fit_lines(sheet: VBoxContainer, name: Label) -> void:
	var wide: float = item_size.x - DOCUMENT_PADDING * 2.0
	var fits: Callable = func(font_size: int) -> bool:
		for line: Label in lines:
			line.add_theme_font_size_override("font_size", font_size)
		return _document_height(sheet, wide) <= item_size.y
	var line_px: int = TextSize.fit(LINE_SIZE, LINE_SIZE, fits)
	fits.call(line_px)
	var font: Font = name.get_theme_font("font")
	var least: int = _one_line_size(font, name.text, item_size.x - DOCUMENT_INSET, NAME_SIZE)
	var name_px: int = name.get_theme_font_size("font_size")
	while name_px > least and _document_height(sheet, wide) > item_size.y:
		name_px -= 1
		name.add_theme_font_size_override("font_size", maxi(name_px, TextSize.least(least)))


## How tall the document's column stands with its wrapped lines set wide, before it is
## laid out: its pieces, the gaps between them and its padding.
func _document_height(sheet: VBoxContainer, wide: float) -> float:
	var tall: float = DOCUMENT_PADDING * 2.0
	var gap: float = float(sheet.get_theme_constant("separation"))
	for child: Node in sheet.get_children():
		var piece: Control = child as Control
		var label: Label = piece as Label
		if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			tall += wrapped_height(label, wide) + gap
		else:
			tall += piece.get_combined_minimum_size().y + gap
	return tall - gap


## How tall a label wrapping between words stands at width wide, from its font.
static func wrapped_height(label: Label, wide: float) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var spacing: float = float(label.get_theme_constant("line_spacing"))
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var block: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size, -1, flags
	)
	var rows: int = maxi(roundi(block.y / font.get_height(font_size)), 1)
	return rows * font.get_height(font_size) + (rows - 1) * spacing


## Sets a Directive's name on one line where a size from NAME_SIZE down to
## DOCUMENT_NAME_LEAST allows, so its Rate lines keep the room; a longer name wraps
## between words at the least size.
func _fit_one_line(name: Label, wide: float) -> void:
	var font: Font = name.get_theme_font("font")
	var font_size: int = _one_line_size(font, title, wide, TextSize.px(NAME_SIZE))
	NameFit.apply(name, title, wide, font_size, TextSize.least(NameFit.LEAST))


## The largest size from start down to DOCUMENT_NAME_LEAST at which text keeps to one line.
static func _one_line_size(font: Font, text: String, wide: float, start: int) -> int:
	var font_size: int = start
	while (
		font_size > TextSize.least(DOCUMENT_NAME_LEAST)
		and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > wide
	):
		font_size -= 1
	return font_size


## A Campaign: its leaflet, as the tray holds it, as large as the place allows.
func show_campaign(controller: RunController, campaign_id: String) -> void:
	title = controller.texts.campaign_name(campaign_id)
	rule = controller.texts.campaign_text(campaign_id)
	var leaflet: CampaignLeaflet = CampaignLeaflet.new()
	leaflet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaflet.show_campaign(
		index, campaign_id, title, "", controller.items.is_private_campaign(campaign_id)
	)
	_set_item(leaflet, CampaignLeaflet.SIZE)


## A plot card: its real face with its chop or rosette, and what the mark does.
func show_card(controller: RunController, kind: int, card: CardInstance) -> void:
	title = controller.texts.envelope_card_text(kind, "name", card)
	rule = controller.texts.envelope_card_text(kind, "text", card)
	var view: CardView = CARD_SCENE.instantiate()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_item(view, view.custom_minimum_size)
	view.bind(card)
	view.visible = true
	# Binding settles the view back to its own scale and pivot.
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE * _fit_scale(view.custom_minimum_size)
	_say(controller.texts.envelope_card_text(kind, "caption", card), ScreenKit.INK)


## Marks whether the item can be kept: when it cannot, its Keep is off and its strip
## says why in dark red. The item stays at full strength either way.
func set_takeable(can: bool, why: String) -> void:
	_takeable = can
	keep.disabled = not can
	if not can:
		_holder.visible = true
		_say(why, REFUSED_INK)


func is_takeable() -> bool:
	return _takeable


## The caption under the item, and its strip, for tests.
func caption() -> String:
	return _caption.text


func caption_label() -> Label:
	return _caption


func caption_strip() -> PanelContainer:
	return _strip


## Pointed at by the mouse, the keyboard or the gamepad: the item lifts a little under a
## gilt frame and its Keep tag. One that cannot be kept stays down under a plain dark
## frame. Under reduced motion nothing moves; the frame and the tag say it.
func set_cursor(on: bool) -> void:
	if on == _cursor:
		return
	_cursor = on
	if on:
		Audio.fill(AudioEvents.MOTION_HOVER)
	_tag.visible = on and _takeable
	if _tag.visible:
		_tag.reset_size()
		_tag.position = Vector2((item_size.x - _tag.size.x) / 2.0, -_tag.size.y / 2.0)
	var to: float = 1.0 if on and _takeable else 0.0
	if _lifting != null and _lifting.is_valid():
		_lifting.kill()
	if UiMotion.reduced() or not is_inside_tree():
		lift = 0.0
	else:
		_lifting = create_tween()
		_lifting.set_trans(Tween.TRANS_BACK if on else Tween.TRANS_CUBIC)
		_lifting.set_ease(Tween.EASE_OUT)
		_lifting.tween_property(self, "lift", to, LIFT_TIME)
	queue_redraw()


## True while the paper is the one pointed at, and whether its Keep tag shows.
func is_pointed() -> bool:
	return _cursor


func shows_keep_tag() -> bool:
	return _tag.visible


## The strip of paper under the item that a caption is printed on, hidden while empty.
func _caption_strip(wide: float) -> Control:
	_holder.custom_minimum_size = Vector2(wide, CAPTION_HEIGHT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_theme_stylebox_override("panel", ScreenKit.paper_style(CAPTION_PADDING))
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.visible = false
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
	_caption.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_caption)
	_holder.add_child(_strip)
	return _holder


func _say(text: String, ink: Color) -> void:
	_caption.text = text
	_caption.add_theme_color_override("font_color", ink)
	_strip.visible = not text.is_empty()


## A scaled item sits in a holder of its scaled size, which its place centres: as large
## as the place allows, keeping its shape.
func _set_item(made: Control, base: Vector2) -> void:
	item = made
	var scale_by: float = _fit_scale(base)
	var holder: Control = Control.new()
	holder.custom_minimum_size = (base * scale_by).floor()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place.add_child(holder)
	holder.add_child(made)
	# Scaled from its corner, so it fills its holder exactly.
	made.pivot_offset = Vector2.ZERO
	made.scale = Vector2.ONE * scale_by


## The scale that fits a piece of base size into the item's place, keeping its shape.
func _fit_scale(base: Vector2) -> float:
	return minf(item_size.x / base.x, item_size.y / base.y)


func _draw() -> void:
	if not _cursor:
		return
	var grown: Vector2 = item_size * _lifted.scale
	var at: Vector2 = _lifted.position + (item_size - grown) / 2.0
	var frame: PackedVector2Array = GiltFrame.path(Rect2(at, grown).grow(FRAME_OFF))
	if not _takeable:
		draw_polyline(frame, REFUSED_INK, 2.0, true)
		return
	GiltFrame.halo(self, frame, HALO_REACH, 0.09)
	GiltFrame.gild(self, frame, 1.0, index)

class_name ChoicePaper
extends Control
## One item in an open envelope (ADR 0021), as a readable paper: a Directive as its typed
## document with each Rate it raises, a Campaign as its leaflet, a plot card as its face
## with its mark plainly on it and a caption saying what the mark does. Under it, Keep.
## One that cannot be kept now is dimmed and says why. Hovering it or focusing its Keep
## asks the envelope's screen to explain it.

## Hovered or focused: the screen should explain this item.
signal pointed(index: int)
signal kept(index: int)

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
const SIZE: Vector2 = Vector2(262, 352)
## The item's own place above its caption and button.
const ITEM: Vector2 = Vector2(262, 244)
const LEAFLET_SCALE: float = 1.3
const CARD_SCALE: float = 1.25
const NAME_SIZE: int = 22
const LINE_SIZE: int = 14
const CAPTION_SIZE: int = 15
const DIM: float = 0.42
const GOLD: Color = Color("c9a227")

var index: int = -1
var keep: Button = ScreenKit.button("", CommonsTheme.COUPON)
## What the screen's explanation shows: the item's name and its full rules.
var title: String = ""
var rule: String = ""
## The Directive's Rate lines, to tick when it is issued; empty for anything else.
var lines: Array[Label] = []
## The item drawn: a document, a leaflet or a card, for the seal and for tests.
var item: Control = null

var _caption: Label = ScreenKit.label("", CAPTION_SIZE)
var _place: CenterContainer = CenterContainer.new()
var _cursor: bool = false
var _takeable: bool = true


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place.custom_minimum_size = ITEM
	_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_place)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.custom_minimum_size = Vector2(SIZE.x, 40)
	_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_caption)
	keep.text = TranslationServer.translate("envelope.keep")
	keep.custom_minimum_size = Vector2(SIZE.x, 0)
	keep.size_flags_horizontal = Control.SIZE_FILL
	column.add_child(keep)
	add_child(column)
	mouse_entered.connect(func() -> void: pointed.emit(index))
	keep.mouse_entered.connect(func() -> void: pointed.emit(index))
	keep.focus_entered.connect(func() -> void: pointed.emit(index))
	keep.pressed.connect(func() -> void: kept.emit(index))


## A Directive: its typed document, a name over one Rate line per hand type it raises.
func show_directive(controller: RunController, directive_id: String) -> void:
	title = controller.directive_name(directive_id)
	rule = controller.directive_text(directive_id)
	var sheet: VBoxContainer = ScreenKit.card(Vector2(ITEM.x - 8, 0))
	sheet.add_theme_constant_override("separation", 4)
	sheet.add_child(ScreenKit.eyebrow(tr(DirectiveSheet.EYEBROW)))
	var name: Label = ScreenKit.label(title, NAME_SIZE)
	name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	sheet.add_child(name)
	sheet.add_child(HSeparator.new())
	for type: int in controller.directive_types(directive_id):
		var line: Label = ScreenKit.label(DirectiveSheet.rate_line(controller, type), LINE_SIZE)
		line.add_theme_font_override("font", ScreenKit.TYPEWRITER)
		sheet.add_child(line)
		lines.append(line)
	item = ScreenKit.card_panel(sheet)
	_place.add_child(item)


## A Campaign: its leaflet, as the tray holds it, larger.
func show_campaign(controller: RunController, campaign_id: String) -> void:
	title = controller.campaign_name(campaign_id)
	rule = controller.campaign_text(campaign_id)
	var leaflet: CampaignLeaflet = CampaignLeaflet.new()
	leaflet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaflet.show_campaign(
		index, campaign_id, title, "", controller.is_private_campaign(campaign_id)
	)
	_set_item(leaflet, CampaignLeaflet.SIZE, LEAFLET_SCALE)


## A plot card: its real face with its chop or rosette, and what the mark does.
func show_card(controller: RunController, kind: int, card: CardInstance) -> void:
	title = controller.envelope_card_text(kind, "name", card)
	rule = controller.envelope_card_text(kind, "text", card)
	var view: CardView = CARD_SCENE.instantiate()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_item(view, view.custom_minimum_size, CARD_SCALE)
	view.bind(card)
	view.visible = true
	_caption.text = controller.envelope_card_text(kind, "caption", card)


## Dims the item with the reason it cannot be kept, or lights it when why is empty.
func set_takeable(can: bool, why: String) -> void:
	_takeable = can
	keep.disabled = not can
	_place.modulate.a = 1.0 if can else DIM
	if not can:
		_caption.text = why
		_caption.add_theme_color_override("font_color", ScreenKit.RED)


func is_takeable() -> bool:
	return _takeable


## The caption under the item, for tests.
func caption() -> String:
	return _caption.text


## Under the keyboard or gamepad cursor: a gold edge under the item.
func set_cursor(on: bool) -> void:
	_cursor = on
	queue_redraw()


## A scaled item sits in a holder of its scaled size, which its place centres.
func _set_item(made: Control, base: Vector2, scale_by: float) -> void:
	item = made
	var holder: Control = Control.new()
	holder.custom_minimum_size = base * scale_by
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place.add_child(holder)
	holder.add_child(made)
	# Scaled from its corner, so it fills its holder exactly.
	made.pivot_offset = Vector2.ZERO
	made.scale = Vector2.ONE * scale_by


func _draw() -> void:
	if not _cursor:
		return
	var edge: Color = CampaignPaper.ink(GOLD, BowlGrime.wear() * 0.5)
	draw_rect(Rect2(Vector2(8, ITEM.y - 2), Vector2(SIZE.x - 16, 4)), edge)

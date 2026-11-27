class_name CounterPanel
extends PanelContainer
## One offer "On the counter" in a shop (ADR 0021): a compact sheet of village paper, a
## Campaign's leaflet, a Reform's decree or a sealed envelope, with the item's kind as an
## eyebrow, its name and its Buy button, all in dark type over the grime. Its full rules
## are in the screen's DetailSlip, which it asks for while it is hovered or its button
## holds focus. Every panel on the counter is one size.

## Hovered or focused: the slip should explain this panel.
signal described(panel: CounterPanel)
## Sent when neither hover nor focus holds the panel any more, so the slip may stop.
signal left(panel: CounterPanel)

## How a panel is drawn, by what it offers: a Campaign's leaflet, a Reform's decree or an envelope.
enum Look { LEAFLET, DECREE, ENVELOPE }

## The size every panel on the counter has, in pixels.
const SIZE: Vector2 = Vector2(195, 122)
## The size of the name before it shrinks to fit, at Standard text.
const NAME_SIZE: int = 21
## A name shrinks this far to stay on one line, then wraps between words.
const LEAST_NAME: int = 16
## The name's width: the panel less its side margins.
const NAME_WIDTH: float = 171.0
## The size of the Buy ticket's words, at Standard text.
const BUY_SIZE: int = 18
## The size of the kind eyebrow, at Standard text.
const KIND_SIZE: int = 13
## How much less padding the compact Buy ticket has above and below its label.
const TIGHTEN: float = 7.0

## The panel's Buy ticket.
var buy: Button = ScreenKit.button("", CommonsTheme.COUPON)
## The item's ID, for the slip.
var item_id: String = ""
## The item's name, for the slip.
var title: String = ""
## The item's full rules, for the slip.
var rule: String = ""

var _look: Look = Look.LEAFLET
var _private: bool = false
## An envelope's wrapping.
var _wrapping: EnvelopeDef.Wrapping = EnvelopeDef.Wrapping.STRING_TIE
var _which: int = 0
var _kind: Label = Label.new()
var _name: Label = Label.new()
var _sold: Label = Label.new()


func _init() -> void:
	custom_minimum_size = SIZE
	# Every paper on the counter stands as tall as the tallest, with one top.
	size_flags_vertical = Control.SIZE_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margins: StyleBoxEmpty = StyleBoxEmpty.new()
	margins.content_margin_left = 12
	margins.content_margin_right = 12
	margins.content_margin_top = 22
	margins.content_margin_bottom = 8
	add_theme_stylebox_override("panel", margins)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_kind.theme_type_variation = CommonsTheme.EYEBROW
	_kind.add_theme_font_size_override("font_size", TextSize.px(KIND_SIZE))
	_name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_name.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	_sold.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_sold.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE + 4))
	_sold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for label: Label in [_kind, _name, _sold]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		column.add_child(label)
	_name.clip_text = false
	buy.custom_minimum_size = Vector2.ZERO
	buy.size_flags_horizontal = Control.SIZE_FILL
	buy.add_theme_font_size_override("font_size", TextSize.px(BUY_SIZE))
	column.add_child(buy)
	add_child(column)
	mouse_entered.connect(func() -> void: described.emit(self))
	mouse_exited.connect(func() -> void: left.emit(self))
	buy.mouse_entered.connect(func() -> void: described.emit(self))
	buy.focus_entered.connect(func() -> void: described.emit(self))
	buy.focus_exited.connect(func() -> void: left.emit(self))


## The Buy ticket keeps its look and its sink when pressed, with less padding, so the
## panel stays compact. Its styles are only known once it is in the tree.
func _ready() -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = buy.get_theme_stylebox(state).duplicate()
		box.content_margin_top = maxf(box.content_margin_top - TIGHTEN, 0.0)
		box.content_margin_bottom = maxf(box.content_margin_bottom - TIGHTEN, 0.0)
		buy.add_theme_stylebox_override(state, box)


## Shows an item for sale: its kind, name and rules, and a Buy button at price.
func offer(
	appearance: Look, kind: String, id: String, name_text: String, rule_text: String, price: String
) -> void:
	_look = appearance
	item_id = id
	title = name_text
	rule = rule_text
	_which = id.hash() & 0xFF
	_kind.text = kind.to_upper()
	_fit_name(name_text)
	buy.text = price
	_kind.visible = true
	_name.visible = true
	buy.visible = true
	_sold.visible = false
	_ink()
	queue_redraw()


## Shows a sold place: the paper with one word on it and no button.
func sold(appearance: Look, word: String) -> void:
	_look = appearance
	item_id = ""
	title = ""
	rule = ""
	_sold.text = word
	_kind.visible = false
	_name.visible = false
	buy.visible = false
	_sold.visible = true
	_ink()
	queue_redraw()


## How an envelope is wrapped.
func set_wrapping(chosen: EnvelopeDef.Wrapping) -> void:
	_wrapping = chosen
	queue_redraw()


## How an envelope is wrapped; it matters only to an envelope's panel.
func wrapping() -> EnvelopeDef.Wrapping:
	return _wrapping


## A private Campaign's leaflet has a black band, as its leaflet in the tray does.
func set_private(on: bool) -> void:
	_private = on
	queue_redraw()


## True for a private Campaign's leaflet, whose band is black.
func is_private() -> bool:
	return _private


## How the panel is drawn, by the kind of offer it holds.
func look() -> Look:
	return _look


## The name as set, for tests.
func name_label() -> Label:
	return _name


## The name on one line, smaller as far as LEAST_NAME, then wrapped between words.
func _fit_name(name_text: String) -> void:
	var least: int = TextSize.least(LEAST_NAME)
	var font_size: int = NameFit.one_line_size(
		ScreenKit.DISPLAY_BOLD, name_text, NAME_WIDTH, TextSize.px(NAME_SIZE), least
	)
	NameFit.apply(_name, name_text, NAME_WIDTH, font_size, TextSize.least(LEAST_NAME))


## The name the panel's label shows, for tests.
func shown_name() -> String:
	return _name.text


## Dark ink with a paper halo, over any grime and at any stage.
func _ink() -> void:
	var halo: Color = CampaignPaper.paper(BowlGrime.wear())
	for label: Label in [_kind, _name, _sold]:
		label.add_theme_color_override("font_color", ScreenKit.INK)
		label.add_theme_color_override("font_outline_color", halo)
		label.add_theme_constant_override("outline_size", CampaignLeaflet.HALO)
	_sold.add_theme_color_override("font_color", ScreenKit.RED)


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var sheet: Rect2 = Rect2(Vector2.ZERO, size)
	if _look == Look.DECREE:
		DecreePaper.poster(self, sheet, worn, _which)
	elif _look == Look.ENVELOPE:
		EnvelopePaper.draw(self, sheet, _wrapping, worn, _which)
	else:
		CampaignPaper.leaflet(self, sheet, _private, worn, _which)

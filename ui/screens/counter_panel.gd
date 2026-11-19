class_name CounterPanel
extends PanelContainer
## One offer "On the counter" in a shop (ADR 0021): a compact sheet of village paper, a
## Campaign's leaflet, a Reform's decree or a sealed envelope, with the item's kind as an
## eyebrow, its name and its Buy button, all in dark type over the grime. Its full rules
## are in the screen's DetailSlip, which it asks for while it is hovered or its button
## holds focus. Every panel on the counter is one size.

## Hovered or focused: the slip should explain this panel. Left: it may stop.
signal described(panel: CounterPanel)
signal left(panel: CounterPanel)

enum Look { LEAFLET, DECREE, ENVELOPE }

const SIZE: Vector2 = Vector2(195, 122)
const NAME_SIZE: int = 21
## A name shrinks this far to stay on one line, then wraps between words.
const LEAST_NAME: int = 16
## The name's width: the panel less its side margins.
const NAME_WIDTH: float = 171.0
const BUY_SIZE: int = 18
const KIND_SIZE: int = 13
## How much less padding the compact Buy ticket has above and below its label.
const TIGHTEN: float = 7.0

var buy: Button = ScreenKit.button("", CommonsTheme.COUPON)
## The item's ID, name and rules, for the slip.
var item_id: String = ""
var title: String = ""
var rule: String = ""

var _look: Look = Look.LEAFLET
var _private: bool = false
## An envelope's wrapping, one of EnvelopePaper's.
var _wrapping: int = EnvelopePaper.STRING_TIE
var _which: int = 0
var _kind: Label = Label.new()
var _name: Label = Label.new()
var _sold: Label = Label.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	look: Look, kind: String, id: String, name_text: String, rule_text: String, price: String
) -> void:
	_look = look
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
func sold(look: Look, word: String) -> void:
	_look = look
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


## How an envelope is wrapped, one of EnvelopePaper's wrappings.
func set_wrapping(wrapping: int) -> void:
	_wrapping = wrapping
	queue_redraw()


func wrapping() -> int:
	return _wrapping


## A private Campaign's leaflet has a black band, as its leaflet in the tray does.
func set_private(on: bool) -> void:
	_private = on
	queue_redraw()


func is_private() -> bool:
	return _private


func look() -> Look:
	return _look


## The name as set, for tests.
func name_label() -> Label:
	return _name


## The name on one line, smaller as far as LEAST_NAME, then wrapped between words.
func _fit_name(name_text: String) -> void:
	var font: Font = ScreenKit.DISPLAY_BOLD
	var font_size: int = TextSize.px(NAME_SIZE)
	while (
		font_size > TextSize.least(LEAST_NAME)
		and font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > NAME_WIDTH
	):
		font_size -= 1
	NameFit.apply(_name, name_text, NAME_WIDTH, font_size, TextSize.least(LEAST_NAME))


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

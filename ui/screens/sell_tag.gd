class_name SellTag
extends Control
## The Sell ticket on a held Cadre's or Campaign's paper in a shop (ADR 0040). It lies
## over the paper's foot while the paper is hovered or holds the focus, and names what a
## sale pays. A sale takes two presses in place: the first turns the ticket to "Sell for
## N?", the second sells. Leaving the paper puts it back, so a stray click never sells.
## A paper whose item cannot be sold now says why on the ticket, off. Enter or the
## gamepad's accept on a focused paper presses the ticket.

## The ticket was pressed a second time: sell.
signal confirmed
## The paper took the focus or lost it, for the screen's slip.
signal focus_changed(focused: bool)

const FONT: int = 16
const HEIGHT: float = 34.0
const WIDTH: float = 84.0
## Up from the paper's foot, inside its border.
const LIFT: float = 2.0

var button: Button = ScreenKit.button("", CommonsTheme.GHOST)

var _host: Control
var _price: int = 0
var _why: String = ""
## The held item the ticket is for, so a question is taken back when another takes its place.
var _item: String = ""
var _asking: bool = false
var _hovered: bool = false
var _focused: bool = false
var _offered: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	button.add_theme_font_size_override("font_size", TextSize.px(FONT))
	BuyTicket.readable(button)
	button.pressed.connect(press)
	add_child(button)
	visible = false


## Lays the ticket over host's foot and follows the pointer and the focus on host.
static func attach(host: Control) -> SellTag:
	var tag: SellTag = SellTag.new()
	tag._host = host
	host.add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.button.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE
	)
	tag.button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tag.button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tag.button.offset_bottom = -LIFT
	host.mouse_entered.connect(tag._on_hover.bind(true))
	host.mouse_exited.connect(tag._on_hover.bind(false))
	host.focus_entered.connect(tag._on_focus.bind(true))
	host.focus_exited.connect(tag._on_focus.bind(false))
	host.gui_input.connect(tag._on_host_input)
	return tag


## The item on the paper, item, sells for price, or cannot be sold now for the reason why.
## A question asked about another item is taken back.
func offer(price: int, why: String = "", item: String = "") -> void:
	if item != _item or price != _price or why != _why:
		_asking = false
	_item = item
	_offered = true
	_price = price
	_why = why
	_host.focus_mode = Control.FOCUS_ALL
	_show()


## The paper holds nothing to sell.
func withdraw() -> void:
	_offered = false
	_asking = false
	_item = ""
	_host.focus_mode = Control.FOCUS_NONE
	_show()


## True while the ticket asks to be pressed again, for tests.
func is_asking() -> bool:
	return _asking


## A press: the first asks, the second sells.
func press() -> void:
	if not _offered or not _why.is_empty() or not visible:
		return
	if _asking:
		_asking = false
		_show()
		confirmed.emit()
		return
	_asking = true
	_show()
	UiMotion.pulse(button)


func _on_hover(on: bool) -> void:
	_hovered = on
	if not on and not _focused:
		_asking = false
	_show()


func _on_focus(on: bool) -> void:
	_focused = on
	if not on and not _hovered:
		_asking = false
	_show()
	focus_changed.emit(on)


func _on_host_input(event: InputEvent) -> void:
	if _focused and event.is_action_pressed("ui_accept"):
		_host.accept_event()
		press()


func _show() -> void:
	visible = _offered and (_hovered or _focused)
	button.disabled = not _why.is_empty()
	if not _why.is_empty():
		button.text = _why
	elif _asking:
		button.text = tr("store.sell.confirm").format({"price": _price})
	else:
		button.text = tr("store.sell").format({"price": _price})

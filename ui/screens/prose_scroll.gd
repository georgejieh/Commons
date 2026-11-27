class_name ProseScroll
extends ScrollContainer
## Prose on its own paper that scrolls when it is too long for the screen (ADR 0034): the
## ending's story and the cheat sheet. Up and down on a keyboard or gamepad scroll it
## while it has focus, and it offers focus only while there is something to scroll to,
## so a sheet that fits reads as before. With a cap, it stands as tall as its content up
## to the cap; without one it fills the room its container gives it.

## How far one up or down press scrolls.
const STEP: int = 90
## The clear gap between the text and the scroll bar while there is one, at every size.
const BAR_GAP: int = 16

## The most it stands, or 0 to take the room its container gives it.
var cap: float = 0.0
var _content: Control = null
## Holds the content, with a margin on its right only while the bar shows.
var _gutter: MarginContainer = MarginContainer.new()


func _init(content: Control) -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	_content = content
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Content that fills the scroll's height, as a death's centred column does, still can.
	_gutter.size_flags_vertical = content.size_flags_vertical
	_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		_gutter.add_theme_constant_override("margin_" + side, 0)
	_gutter.add_child(content)
	add_child(_gutter)
	content.minimum_size_changed.connect(_fit)
	get_v_scroll_bar().changed.connect(_update_focus)


## Stands as tall as the content, up to at most.
func fit_to(at_most: float) -> void:
	cap = at_most
	_fit()


func _fit() -> void:
	var tall: float = _content.get_combined_minimum_size().y
	custom_minimum_size.y = 0.0 if cap <= 0.0 else minf(tall, cap)


## Focus is offered only while there is something to scroll to, and the gap at the bar
## opens only while there is a bar.
func _update_focus() -> void:
	var bar: VScrollBar = get_v_scroll_bar()
	var scrolls: bool = bar.max_value > bar.page + 1.0
	focus_mode = Control.FOCUS_ALL if scrolls else Control.FOCUS_NONE
	_gutter.add_theme_constant_override("margin_right", BAR_GAP if scrolls else 0)


## True while there is something to scroll to, which is also while it takes focus; for tests.
func can_scroll() -> bool:
	return focus_mode == Control.FOCUS_ALL


func _gui_input(event: InputEvent) -> void:
	var bar: VScrollBar = get_v_scroll_bar()
	var bottom: float = bar.max_value - bar.page
	if event.is_action_pressed("ui_down") and scroll_vertical < bottom - 1.0:
		scroll_vertical += STEP
		accept_event()
	elif event.is_action_pressed("ui_up") and scroll_vertical > 0:
		scroll_vertical -= STEP
		accept_event()

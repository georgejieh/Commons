class_name ActionBar
extends VBoxContainer
## What the player can do on their turn: the selection's reading and projected score,
## Play and Pass, Sit out beside Pass when nothing the player holds can answer the trick
## (SitOut), and the Hint, Sort and Rules toggles. Bidding swaps in Call and Pass,
## and the opening before the first play, where a Campaign may be used, swaps in Play on.
## The column is held at its foot and its width (ADR 0034): a taller prompt grows it up
## into the empty table, and the toggles' type fits the width, never under Standard. The
## prompt has a box as tall as the tallest prompt stands at its Standard type (rule 10):
## a prompt that would stand taller at a larger text size fits its type down into the
## box, never under Standard, so the column never stands taller than it does at Standard.

## The toggles' type at Standard.
const TOGGLE_SIZE: int = 18
## The prompt's type at Standard.
const PROMPT_SIZE: int = 24

var reading: Label = Label.new()
var play: Button = Button.new()
var pass_turn: Button = Button.new()
var sit_out: Button = Button.new()
var hint: Button = Button.new()
var sort: Button = Button.new()
var rules: Button = Button.new()
var call: Button = Button.new()
var decline: Button = Button.new()
var play_on: Button = Button.new()

var _turn_row: VBoxContainer = VBoxContainer.new()
var _pass_row: HBoxContainer = HBoxContainer.new()
var _bid_row: HBoxContainer = HBoxContainer.new()
var _toggles: HBoxContainer = HBoxContainer.new()
## Where the column stands: its left edge, width and foot.
var _held: Rect2 = Rect2()
## The prompt's box: how tall the tallest prompt stands at its Standard type. Every prompt
## fits until size_prompt() measures it.
var _prompt_room: float = INF


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	# The buttons stand at the column's foot whatever the prompt's length: a prompt of two
	# lines grows up from them, and nothing under the pointer moves.
	alignment = BoxContainer.ALIGNMENT_END
	reading.theme_type_variation = CommonsTheme.TITLE
	reading.add_theme_font_size_override("font_size", TextSize.px(PROMPT_SIZE))
	ScreenKit.paper_outline(reading)
	reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(reading)
	_button(play, "action.play", CommonsTheme.PRIMARY)
	_button(pass_turn, "action.pass", CommonsTheme.SECONDARY)
	_button(sit_out, "action.sit_out", CommonsTheme.SECONDARY)
	sit_out.tooltip_text = tr("action.sit_out_tip")
	sit_out.visible = false
	_turn_row.add_child(play)
	for button: Button in [pass_turn, sit_out]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pass_row.add_child(button)
	_turn_row.add_child(_pass_row)
	var toggles: Array[Button] = [hint, sort, rules]
	var keys: Array[String] = ["action.hint", "action.sort", "action.rules"]
	for index: int in toggles.size():
		var button: Button = toggles[index]
		_button(button, keys[index], CommonsTheme.GHOST)
		button.add_theme_font_size_override("font_size", TextSize.px(TOGGLE_SIZE))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_toggles.add_child(button)
	hint.tooltip_text = tr("action.hint_tip")
	hint.visible = HintSetting.shown()
	Settings.changed.connect(_on_setting)
	_turn_row.add_child(_toggles)
	add_child(_turn_row)
	_button(call, "action.call", CommonsTheme.PRIMARY)
	_button(decline, "action.decline", CommonsTheme.SECONDARY)
	for button: Button in [call, decline]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bid_row.add_child(button)
	add_child(_bid_row)
	_button(play_on, "action.play_on", CommonsTheme.PRIMARY)
	add_child(play_on)
	show_bidding(false)


## Stands the column in box: its left edge and foot there, as wide as box or as the
## toggles at Standard with the longest sort, whichever is wider. The toggles' type fits
## that width; a taller column grows upward from the foot.
func hold(box: Rect2) -> void:
	var wide: float = maxf(box.size.x, ceilf(_toggles_width(TextSize.least(TOGGLE_SIZE))))
	var fits: Callable = func(font_size: int) -> bool: return _toggles_width(font_size) <= wide
	var font_size: int = TextSize.fit(TOGGLE_SIZE, TOGGLE_SIZE, fits)
	for button: Button in [hint, sort, rules]:
		button.add_theme_font_size_override("font_size", font_size)
	_held = Rect2(box.position, Vector2(wide, box.size.y))
	# The prompt wraps at the column's width from the start, so it can be measured.
	reading.custom_minimum_size.x = wide
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	size = _held.size
	position = Vector2(_held.position.x, _held.end.y - size.y)


## Measures the prompt's box from every prompt the line can show, playing and bidding, at
## the prompt's Standard type and the column's width. Call after hold().
func size_prompt(prompts: Array[String]) -> void:
	var room: float = 0.0
	for prompt: String in prompts:
		room = maxf(room, _prompt_height(prompt, TextSize.least(PROMPT_SIZE)))
	_prompt_room = room
	_fit_prompt()


## Shows text on the prompt line, with tip as its tooltip: at the chosen text size, or
## where that would stand taller than the prompt's box, fitted down into it, never under
## Standard.
func say(text: String, tip: String = "") -> void:
	reading.text = text
	reading.tooltip_text = tip
	_fit_prompt()


## How tall the column stands with the prompt's box over the play set, or over Call and
## Pass when bidding.
func tallest(bidding: bool) -> float:
	var row: Control = _bid_row if bidding else _turn_row
	return _prompt_room + get_theme_constant("separation") + row.get_combined_minimum_size().y


## The prompt line's type now, for tests.
func prompt_size() -> int:
	return reading.get_theme_font_size("font_size")


## The prompt's box, for tests.
func prompt_room() -> float:
	return _prompt_room


## Where the column was stood: its left edge, width and foot, for the table and tests.
func held() -> Rect2:
	return _held


func _fit_prompt() -> void:
	var text: String = reading.text
	var fits: Callable = func(font_size: int) -> bool:
		return _prompt_height(text, font_size) <= _prompt_room
	var font_size: int = TextSize.fit(PROMPT_SIZE, PROMPT_SIZE, fits)
	reading.add_theme_font_size_override("font_size", font_size)


## How tall the prompt line stands holding text at font_size, at the column's width. The
## box and the fit both measure here, so they cannot disagree.
func _prompt_height(text: String, font_size: int) -> float:
	var shown: String = reading.text
	var was: int = reading.get_theme_font_size("font_size")
	reading.text = text
	reading.add_theme_font_size_override("font_size", font_size)
	var tall: float = reading.get_minimum_size().y
	reading.text = shown
	reading.add_theme_font_size_override("font_size", was)
	return tall


## The toggles' row as wide as it stands at font_size, with the longest sort it can show.
func _toggles_width(font_size: int) -> float:
	var sorts: Array[String] = [tr("action.sort")]
	for key: String in HandView.SORT_KEYS.values():
		sorts.append(tr("action.sort_by").format({"mode": tr(key)}))
	var longest: float = 0.0
	for named: String in sorts:
		longest = maxf(longest, _width(named, font_size))
	var edges: float = hint.get_theme_stylebox("normal").get_minimum_size().x
	var wide: float = _toggles.get_theme_constant("separation") * 2.0 + longest + edges * 3.0
	return wide + _width(tr("action.hint"), font_size) + _width(tr("action.rules"), font_size)


func _width(text: String, font_size: int) -> float:
	var font: Font = hint.get_theme_font("font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func show_bidding(on: bool) -> void:
	_bid_row.visible = on
	_turn_row.visible = not on
	play_on.visible = false


## Sit out stands beside Pass only while it is offered.
func show_sit_out(on: bool) -> void:
	sit_out.visible = on


## The opening: Play on in place of the turn's buttons.
func show_opening(on: bool) -> void:
	play_on.visible = on
	_turn_row.visible = not on and not _bid_row.visible


## The Hint shows only while the player keeps it on; the prompt takes a new text size
## at once.
func _on_setting(key: String) -> void:
	if key == HintSetting.SETTING:
		hint.visible = HintSetting.shown()
	if key == TextSize.SETTING:
		_fit_prompt()


func _button(button: Button, key: String, kind: String) -> void:
	button.text = tr(key)
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = kind
	UiMotion.hoverable(button)

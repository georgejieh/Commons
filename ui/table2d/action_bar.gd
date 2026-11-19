class_name ActionBar
extends VBoxContainer
## What the player can do on their turn: the selection's reading and projected score,
## Play and Pass, and the Hint, Sort and Rules toggles. Bidding swaps in Call and Pass,
## and the opening before the first play, where a Campaign may be used, swaps in Play on.
## The column is held at its foot and its width (ADR 0034): a taller prompt grows it up
## into the empty table, and the toggles' type fits the width, never under Standard.

## The toggles' type at Standard.
const TOGGLE_SIZE: int = 18

var reading: Label = Label.new()
var play: Button = Button.new()
var pass_turn: Button = Button.new()
var hint: Button = Button.new()
var sort: Button = Button.new()
var rules: Button = Button.new()
var call: Button = Button.new()
var decline: Button = Button.new()
var play_on: Button = Button.new()

var _turn_row: VBoxContainer = VBoxContainer.new()
var _bid_row: HBoxContainer = HBoxContainer.new()
var _toggles: HBoxContainer = HBoxContainer.new()
## Where the column stands: its left edge, width and foot.
var _held: Rect2 = Rect2()


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	reading.theme_type_variation = CommonsTheme.TITLE
	reading.add_theme_font_size_override("font_size", TextSize.px(24))
	ScreenKit.paper_outline(reading)
	reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(reading)
	_button(play, "action.play", CommonsTheme.PRIMARY)
	_button(pass_turn, "action.pass", CommonsTheme.SECONDARY)
	_turn_row.add_child(play)
	_turn_row.add_child(pass_turn)
	for pair: Array in [[hint, "action.hint"], [sort, "action.sort"], [rules, "action.rules"]]:
		var button: Button = pair[0]
		_button(button, pair[1], CommonsTheme.GHOST)
		button.add_theme_font_size_override("font_size", TextSize.px(TOGGLE_SIZE))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_toggles.add_child(button)
	hint.tooltip_text = tr("action.hint_tip")
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
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	size = _held.size
	position = Vector2(_held.position.x, _held.end.y - size.y)


## Where the column was stood: its left edge, width and foot, for the table and tests.
func held() -> Rect2:
	return _held


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


## The opening: Play on in place of the turn's buttons.
func show_opening(on: bool) -> void:
	play_on.visible = on
	_turn_row.visible = not on and not _bid_row.visible


func _button(button: Button, key: String, kind: String) -> void:
	button.text = tr(key)
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = kind
	UiMotion.hoverable(button)

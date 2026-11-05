class_name ActionBar
extends VBoxContainer
## What the player can do on their turn: the selection's reading and projected score,
## Play and Pass, and the Hint, Sort and Rules toggles. Bidding swaps in Call and Pass.

var reading: Label = Label.new()
var play: Button = Button.new()
var pass_turn: Button = Button.new()
var hint: Button = Button.new()
var sort: Button = Button.new()
var rules: Button = Button.new()
var call: Button = Button.new()
var decline: Button = Button.new()

var _turn_row: VBoxContainer = VBoxContainer.new()
var _bid_row: HBoxContainer = HBoxContainer.new()


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	reading.theme_type_variation = CommonsTheme.TITLE
	reading.add_theme_font_size_override("font_size", 24)
	reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(reading)
	_button(play, "action.play", CommonsTheme.PRIMARY)
	_button(pass_turn, "action.pass", CommonsTheme.SECONDARY)
	_turn_row.add_child(play)
	_turn_row.add_child(pass_turn)
	var toggles: HBoxContainer = HBoxContainer.new()
	for pair: Array in [[hint, "action.hint"], [sort, "action.sort"], [rules, "action.rules"]]:
		var button: Button = pair[0]
		_button(button, pair[1], CommonsTheme.GHOST)
		button.add_theme_font_size_override("font_size", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggles.add_child(button)
	hint.tooltip_text = tr("action.hint_tip")
	_turn_row.add_child(toggles)
	add_child(_turn_row)
	_button(call, "action.call", CommonsTheme.PRIMARY)
	_button(decline, "action.decline", CommonsTheme.SECONDARY)
	for button: Button in [call, decline]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bid_row.add_child(button)
	add_child(_bid_row)
	show_bidding(false)


func show_bidding(on: bool) -> void:
	_bid_row.visible = on
	_turn_row.visible = not on


func _button(button: Button, key: String, kind: String) -> void:
	button.text = tr(key)
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = kind
	UiMotion.hoverable(button)

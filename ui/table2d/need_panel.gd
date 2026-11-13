class_name NeedPanel
extends PanelContainer
## Asks the player to declare need before the Commons is split. It shows what the pool
## holds and what a declaration would pay if the teammate declared honestly, so the
## number is never abstract. Any value is allowed; a declaration above true need is a
## lie, and an audit that catches it costs Denunciation (P4.3).

signal declared(need: int)

const WIDTH: float = 460.0
const LIE: Color = Color("9e1b16")

var _need: int = 0
var _true_need: int = 0
var _cap: int = 0
var _lie_cost: int = 0
var _pool_units: int = 0
var _mate: String = ""
var _pool: Label = Label.new()
var _value: Label = Label.new()
var _less: Button = ScreenKit.button("−", CommonsTheme.GHOST)
var _more: Button = ScreenKit.button("+", CommonsTheme.GHOST)
var _preview: Label = Label.new()
var _note: Label = Label.new()
var _declare: Button = ScreenKit.button("", CommonsTheme.PRIMARY)


func _ready() -> void:
	theme_type_variation = CommonsTheme.SHEET
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(ScreenKit.styled(tr("need.title"), CommonsTheme.TITLE))
	_value.theme_type_variation = CommonsTheme.TITLE
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.custom_minimum_size = Vector2(90, 0)
	for button: Button in [_less, _more]:
		button.custom_minimum_size = Vector2(64, 0)
		button.focus_mode = Control.FOCUS_NONE
	_less.pressed.connect(_step.bind(-1))
	_more.pressed.connect(_step.bind(1))
	var stepper: HBoxContainer = HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	for child: Control in [_less, _value, _more]:
		stepper.add_child(child)
	_declare.text = tr("need.declare")
	_declare.size_flags_horizontal = Control.SIZE_FILL
	_declare.pressed.connect(func() -> void: declared.emit(_need))
	var rule: Label = Label.new()
	rule.name = "Rule"
	for label: Label in [_pool, rule, _preview, _note]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(WIDTH, 0)
	_pool.mouse_filter = Control.MOUSE_FILTER_STOP
	_pool.tooltip_text = tr("keyword.commons.text")
	for child: Control in [_pool, rule, stepper, _preview, _note, _declare]:
		box.add_child(child)
	add_child(box)
	visible = false


## Starts the choice at a fair need, with the most a declaration may claim and what a
## caught lie costs.
func setup(default_need: int, cap: int, lie_cost: int = 0) -> void:
	_true_need = default_need
	_need = default_need
	_cap = cap
	_lie_cost = lie_cost
	var rule: Label = find_child("Rule", true, false)
	rule.text = tr("need.rule").format({"need": default_need})
	_show()


## Shows the panel for a pool of pool_units, shared with the teammate named mate. The
## last value is kept. Declare takes focus, so Enter or the gamepad's A declares and up
## and down change the value.
func ask(pool_units: int = 0, mate: String = "") -> void:
	_pool_units = pool_units
	_mate = mate
	_show()
	visible = true
	size = Vector2.ZERO
	_declare.grab_focus()


## The need that Declare would send.
func value() -> int:
	return _need


## What this declaration pays the player if the teammate declares true need.
func preview_share() -> int:
	return Banking.split(_pool_units, PackedInt64Array([_need, _true_need]))[0]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_up", true):
		_step(1)
	elif event.is_action_pressed("ui_down", true):
		_step(-1)
	else:
		return
	get_viewport().set_input_as_handled()


func _step(by: int) -> void:
	_need = clampi(_need + by, 0, _cap)
	_show()


func _show() -> void:
	_value.text = str(_need)
	_less.disabled = _need <= 0
	_more.disabled = _need >= _cap
	_pool.text = tr("need.pool").format({"pool": Strings.score(_pool_units)})
	var yours: int = preview_share()
	_preview.text = (
		tr("need.preview")
		. format(
			{
				"name": _mate,
				"base": _true_need,
				"yours": Strings.score(yours),
				"theirs": Strings.score(_pool_units - yours),
			}
		)
	)
	var lie: bool = _need > _true_need
	_value.add_theme_color_override("font_color", LIE if lie else ScreenKit.INK)
	_note.add_theme_color_override("font_color", LIE if lie else ScreenKit.INK)
	if lie:
		_note.text = tr("need.lie").format({"rise": _lie_cost})
	elif _need < _true_need:
		_note.text = tr("need.less").format({"name": _mate})
	else:
		_note.text = tr("need.honest")

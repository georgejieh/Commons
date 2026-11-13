class_name NeedPanel
extends PanelContainer
## Asks the player how much of the Commons to claim before it is split. The claim is
## shown as a share of the pool, with what it would pay if the teammate claimed a fair
## half, so the number is never abstract. Under it the claim is still a declared need:
## the pool is split in proportion to the two needs, and equal needs split it evenly.
## A claim above the fair half is a lie, and an audit that catches it costs
## Denunciation (P4.3).

signal declared(need: int)

const WIDTH: float = 440.0
const LIE: Color = Color("9e1b16")
const DECLARE_WIDTH: float = 240.0

## Where the panel's middle sits; it grows and shrinks around this point.
var center: Vector2 = Vector2.ZERO

var _need: int = 0
var _true_need: int = 0
var _cap: int = 0
var _lie_cost: int = 0
var _audit_percent: int = 0
var _pool_units: int = 0
var _mate: String = ""
var _pool: Label = Label.new()
var _rule: Label = Label.new()
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
	_value.custom_minimum_size = Vector2(120, 0)
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
	_declare.custom_minimum_size = Vector2(DECLARE_WIDTH, 0)
	_declare.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_declare.pressed.connect(func() -> void: declared.emit(_need))
	for label: Label in [_pool, _rule, _preview, _note]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(WIDTH, 0)
	_pool.mouse_filter = Control.MOUSE_FILTER_STOP
	_pool.tooltip_text = Keywords.wrapped(tr("keyword.commons.text"))
	_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_note.tooltip_text = Keywords.wrapped(tr("keyword.audit.text"))
	for child: Control in [_pool, _rule, stepper, _preview, _note, _declare]:
		box.add_child(child)
	add_child(box)
	visible = false


## Starts the choice at the fair need, with the most a declaration may claim and what a
## caught lie costs.
func setup(default_need: int, cap: int, lie_cost: int = 0) -> void:
	_true_need = default_need
	_need = default_need
	_cap = cap
	_lie_cost = lie_cost
	_show()


## Shows the panel for a pool of pool_units, shared with the teammate named mate, with
## each claim audited at audit_chance (0 to 1). The last claim is kept. Declare takes
## focus, so Enter or the gamepad's A declares and up and down change the claim.
func ask(pool_units: int = 0, mate: String = "", audit_chance: float = 0.0) -> void:
	_pool_units = pool_units
	_mate = mate
	_audit_percent = roundi(audit_chance * 100.0)
	_show()
	visible = true
	_declare.grab_focus()


## The need that Declare would send.
func value() -> int:
	return _need


## The share of the pool this claim asks for, in percent, against a fair teammate.
func percent() -> int:
	return NeedPanel.share_percent(_need, _true_need)


## A need's share of the pool, in percent, against another need.
static func share_percent(need: int, other: int) -> int:
	if need + other <= 0:
		return 0
	return roundi(100.0 * need / (need + other))


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
	_value.text = tr("need.percent").format({"percent": percent()})
	_less.disabled = _need <= 0
	_more.disabled = _need >= _cap
	_pool.text = tr("need.pool").format({"pool": Strings.score(_pool_units)})
	_rule.text = tr("need.rule").format({"name": _mate})
	var yours: int = preview_share()
	_preview.text = (
		tr("need.preview")
		. format(
			{
				"name": _mate,
				"yours": Strings.score(yours),
				"theirs": Strings.score(_pool_units - yours),
			}
		)
	)
	var lie: bool = _need > _true_need
	_value.add_theme_color_override("font_color", LIE if lie else ScreenKit.INK)
	_note.add_theme_color_override("font_color", LIE if lie else ScreenKit.INK)
	if lie:
		_note.text = tr("need.lie").format({"rise": _lie_cost, "chance": _audit_percent})
	elif _need < _true_need:
		_note.text = tr("need.less").format({"name": _mate})
	else:
		_note.text = tr("need.honest").format({"chance": _audit_percent})
	_fit.call_deferred()


## Shrinks the sheet to its text and keeps it centered. Wrapped labels only know their
## height once laid out, so this runs a frame after the text changes.
func _fit() -> void:
	for _pass: int in 2:
		reset_size()
		if center != Vector2.ZERO:
			position = center - size / 2.0
		if not is_inside_tree():
			return
		await get_tree().process_frame

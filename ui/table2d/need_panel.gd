class_name NeedPanel
extends PanelContainer
## Asks the player to declare need before the Commons is split. Any value is allowed;
## a lie risks Denunciation once audits arrive (P4.3).

signal declared(need: int)

var _spin: SpinBox = SpinBox.new()
var _declare: Button = Button.new()


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var prompt: Label = Label.new()
	prompt.text = tr("need.prompt")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(360, 0)
	_spin.min_value = 0
	_declare.text = tr("need.declare")
	_declare.pressed.connect(_declare_now)
	_spin.get_line_edit().text_submitted.connect(
		func(text: String) -> void:
			_spin.value = text.to_int()
			_declare_now()
	)
	for child: Control in [prompt, _spin, _declare]:
		box.add_child(child)
	add_child(box)
	visible = false


## Starts the choice at a fair need, with the most a declaration may claim.
func setup(default_need: int, cap: int) -> void:
	_spin.max_value = cap
	_spin.value = default_need


## Shows the panel with the last value kept. Declare takes focus, so Enter or the
## gamepad's A declares and up and down change the value.
func ask() -> void:
	visible = true
	_declare.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_up", true):
		_spin.value += _spin.step
	elif event.is_action_pressed("ui_down", true):
		_spin.value -= _spin.step
	else:
		return
	get_viewport().set_input_as_handled()


func _declare_now() -> void:
	declared.emit(int(_spin.value))

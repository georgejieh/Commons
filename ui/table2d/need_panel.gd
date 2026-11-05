class_name NeedPanel
extends PanelContainer
## Asks the player to declare need before the Commons is split. Any value is allowed;
## a lie risks Denunciation once audits arrive (P4.3).

signal declared(need: int)

var _spin: SpinBox = SpinBox.new()


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var prompt: Label = Label.new()
	prompt.text = tr("need.prompt")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(360, 0)
	_spin.min_value = 0
	var button: Button = Button.new()
	button.text = tr("need.declare")
	button.pressed.connect(func() -> void: declared.emit(int(_spin.value)))
	for child: Control in [prompt, _spin, button]:
		box.add_child(child)
	add_child(box)
	visible = false


## Starts the choice at a fair need, with the most a declaration may claim.
func setup(default_need: int, cap: int) -> void:
	_spin.max_value = cap
	_spin.value = default_need


## Shows the panel with the last value kept.
func ask() -> void:
	visible = true
	_spin.get_line_edit().grab_focus()

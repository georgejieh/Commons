class_name NeedPanel
extends PanelContainer
## Asks the player to declare need before the Commons is split. Any value is allowed;
## a lie risks Denunciation once audits arrive (P4.3).

signal declared(need: int)

const MAX_NEED: int = 99

var _spin: SpinBox = SpinBox.new()


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var prompt: Label = Label.new()
	prompt.text = tr("need.prompt")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(360, 0)
	_spin.min_value = 0
	_spin.max_value = MAX_NEED
	var button: Button = Button.new()
	button.text = tr("need.declare")
	button.pressed.connect(func() -> void: declared.emit(int(_spin.value)))
	for child: Control in [prompt, _spin, button]:
		box.add_child(child)
	add_child(box)
	visible = false


## Shows the panel with the last value kept.
func ask() -> void:
	visible = true
	_spin.get_line_edit().grab_focus()

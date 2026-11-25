class_name SettingChoices
extends HBoxContainer
## One setting picked from a few named boxes on the settings sheet: the setting's name,
## then a box for each value, the chosen one ticked. The boxes are one group, so arrows
## move between them and accept picks one, and they wrap under each other where the
## sheet is too narrow for them on one line. The tick follows the setting when anything
## else changes it, as when a new display goes back unkept.

var _key: String
var _boxes: Dictionary[int, CheckBox] = {}
var _enabled_when: Callable


## choices maps each value of the setting to its words, in the order shown; box_name has
## one %d for the value, naming each box for the focus and for tests. While enabled_when,
## if given, is false the boxes cannot be picked.
func _init(
	key: String,
	label: Label,
	choices: Dictionary[int, String],
	box_name: String,
	enabled_when: Callable = Callable()
) -> void:
	_key = key
	_enabled_when = enabled_when
	add_theme_constant_override("separation", ScreenKit.STYLE.gap)
	add_child(label)
	var flow: HFlowContainer = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", ScreenKit.STYLE.gap)
	add_child(flow)
	var group: ButtonGroup = ButtonGroup.new()
	for value: int in choices:
		var box: CheckBox = CheckBox.new()
		box.name = box_name % value
		box.button_group = group
		box.text = choices[value]
		box.toggled.connect(_on_toggled.bind(value))
		flow.add_child(box)
		_boxes[value] = box
	_show()


func _enter_tree() -> void:
	Settings.changed.connect(_on_setting)


func _exit_tree() -> void:
	Settings.changed.disconnect(_on_setting)


## The box for value, or null when it is not offered.
func box(value: int) -> CheckBox:
	return _boxes.get(value, null)


func _on_toggled(on: bool, value: int) -> void:
	if on and value != int(Settings.value(_key)):
		Settings.set_value(_key, value)


func _on_setting(_changed: String) -> void:
	_show()


## Ticks the box of the value held now, without picking it again, and closes the boxes
## while they cannot be picked.
func _show() -> void:
	var held: CheckBox = box(_held())
	var enabled: bool = not _enabled_when.is_valid() or bool(_enabled_when.call())
	for value: int in _boxes:
		_boxes[value].set_pressed_no_signal(_boxes[value] == held)
		_boxes[value].disabled = not enabled


## The value whose box is ticked: the one held, or for a value that has no box, as from a
## damaged file or a window size the screen cannot hold, the nearest offered below it.
func _held() -> int:
	var chosen: int = int(Settings.value(_key))
	var held: int = int(_boxes.keys().min())
	for value: int in _boxes:
		if value <= chosen:
			held = maxi(held, value)
	return held

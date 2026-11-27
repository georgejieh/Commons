class_name TestInput
extends RefCounted
## A player's presses for tests. Each goes through Input as a real press does, down and
## then up, so it reaches whatever handles it the way the player's would; the suite then
## waits two frames for what the press set off.


## Presses and lets go of the key code.
static func tap_key(suite: GdUnitTestSuite, code: Key) -> void:
	for down: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	await _settle(suite)


## Presses and lets go of a pad's button.
static func tap_pad(suite: GdUnitTestSuite, button: JoyButton) -> void:
	for down: bool in [true, false]:
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = button
		pad.pressed = down
		Input.parse_input_event(pad)
		Input.flush_buffered_events()
	await _settle(suite)


## Sends event into the suite's viewport, its position in the viewport's own pixels: a
## mouse event reaches the control under its position, any other the control with the focus.
static func push(suite: GdUnitTestSuite, event: InputEvent) -> void:
	suite.get_viewport().push_input(event, true)


## Presses the shown button under root whose words are text, as a click does, and fails
## suite when there is none.
static func press(suite: GdUnitTestSuite, root: Node, text: String) -> void:
	for button: Node in root.find_children("*", "BaseButton", true, false):
		if button is Button and (button as Button).text == text:
			if (button as Button).is_visible_in_tree():
				(button as Button).pressed.emit()
				return
	suite.fail("No button reads %s" % text)


static func _settle(suite: GdUnitTestSuite) -> void:
	await suite.await_idle_frame()
	await suite.await_idle_frame()

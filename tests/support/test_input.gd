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


static func _settle(suite: GdUnitTestSuite) -> void:
	await suite.await_idle_frame()
	await suite.await_idle_frame()

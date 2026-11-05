extends GdUnitTestSuite
## A full round can be played with each input method (P3B.11): mouse clicks on cards and
## buttons, the keyboard alone, and a gamepad alone. Every input goes through the
## engine's input path, as a player's would.

enum Method { MOUSE, KEYBOARD, GAMEPAD }

const SEED: int = 4301
const SAVE_PATH: String = "user://test_input_methods/run.json"
const MAX_STEPS: int = 400
## Inside a card's uncovered left strip, clear of the next card in the fan.
const GRIP: Vector2 = Vector2(14, 60)
const KEYS: Dictionary[String, Key] = {
	"play": KEY_ENTER,
	"pass": KEY_SPACE,
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"select": KEY_UP,
	"accept": KEY_ENTER,
}
const PAD: Dictionary[String, JoyButton] = {
	"play": JOY_BUTTON_X,
	"pass": JOY_BUTTON_Y,
	"left": JOY_BUTTON_DPAD_LEFT,
	"right": JOY_BUTTON_DPAD_RIGHT,
	"select": JOY_BUTTON_A,
	"accept": JOY_BUTTON_A,
}

var _app: DemoApp
var _table: TableScreen
var _plays: int = 0


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	_table = _app.show_screen("table", true)
	await await_idle_frame()
	_plays = 0


func after_test() -> void:
	Saves.run_service().delete()


func test_a_round_with_the_mouse() -> void:
	await _play_round(Method.MOUSE)


func test_a_round_with_the_keyboard() -> void:
	await _play_round(Method.KEYBOARD)


func test_a_round_with_a_gamepad() -> void:
	await _play_round(Method.GAMEPAD)


func _play_round(method: Method) -> void:
	var driver: ControllerScript = ControllerScript.new()
	var start: int = _app.controller.state_copy().round_index
	for _step: int in MAX_STEPS:
		if _round_over(start):
			break
		_table.skip_events()
		await await_idle_frame()
		if _round_over(start):
			break
		match _app.controller.awaiting():
			RunController.AWAIT_BID:
				await _press_action(method, "pass", _table.actions().decline)
			RunController.AWAIT_NEED:
				await _declare(method)
			RunController.AWAIT_PLAY:
				await _take_turn(method, driver)
	assert_bool(_round_over(start)).is_true()
	assert_int(_plays).is_greater(0)


func _round_over(start: int) -> bool:
	return _app.switcher.current_id() != "table" or _app.controller.state_copy().round_index > start


func _take_turn(method: Method, driver: ControllerScript) -> void:
	var ids: Array[int] = driver.choose_play(_app.controller)
	if ids.is_empty():
		await _press_action(method, "pass", _table.actions().pass_turn)
		return
	for card_id: int in ids:
		await _pick(method, card_id)
	assert_array(_app.hand.selected_ids()).contains_exactly_in_any_order(ids)
	var before: int = _app.controller.player_cards().size()
	await _press_action(method, "play", _table.actions().play)
	assert_int(_app.controller.player_cards().size()).is_equal(before - ids.size())
	_plays += 1


func _pick(method: Method, card_id: int) -> void:
	var hand_view: HandView = _table.get("_hand_view")
	if method == Method.MOUSE:
		var view: CardView = _view_for(hand_view, card_id)
		await _click(view.get_global_transform_with_canvas() * GRIP)
		return
	if hand_view.cursor_card() == -1:
		await _send(method, "right")
	var guard: int = 0
	while hand_view.cursor_card() != card_id and guard < 40:
		guard += 1
		var target: int = _index_of(hand_view, card_id)
		var here: int = _index_of(hand_view, hand_view.cursor_card())
		await _send(method, "right" if target > here else "left")
	await _send(method, "select")


func _declare(method: Method) -> void:
	if method == Method.MOUSE:
		var panel: NeedPanel = _table.need_panel()
		await _click(_center(panel.get("_declare")))
	else:
		await _send(method, "accept")


func _press_action(method: Method, action: String, button: Button) -> void:
	if method == Method.MOUSE:
		await _click(_center(button))
	else:
		await _send(method, action)


func _send(method: Method, action: String) -> void:
	for down: bool in [true, false]:
		if method == Method.KEYBOARD:
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = KEYS[action]
			key.keycode = KEYS[action]
			key.pressed = down
			Input.parse_input_event(key)
		else:
			var pad: InputEventJoypadButton = InputEventJoypadButton.new()
			pad.button_index = PAD[action]
			pad.pressed = down
			Input.parse_input_event(pad)
		Input.flush_buffered_events()
	await await_idle_frame()


func _click(canvas_point: Vector2) -> void:
	var at: Vector2 = get_tree().root.get_final_transform() * canvas_point
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for down: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.position = at
		click.global_position = at
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(click)
	Input.flush_buffered_events()
	await await_idle_frame()


func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


func _view_for(hand_view: HandView, card_id: int) -> CardView:
	for child: Node in hand_view.get_children():
		var view: CardView = child as CardView
		if view != null and view.visible and view.card_id == card_id:
			return view
	return null


func _index_of(hand_view: HandView, card_id: int) -> int:
	var index: int = 0
	for child: Node in hand_view.get_children():
		var view: CardView = child as CardView
		if view != null and view.visible:
			if view.card_id == card_id:
				return index
			index += 1
	return -1

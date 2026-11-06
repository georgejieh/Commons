extends GdUnitTestSuite
## Hand interaction through real mouse input (P3B.4): press, drag across cards and
## release select or clear them, and the Play button and reading follow the selection.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_hand_drag/run.json"
## Inside a card's uncovered left strip, clear of the next card in the fan.
const GRIP: Vector2 = Vector2(14, 60)

var _app: DemoApp
var _table: TableScreen


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	_table = _app.show_screen("table", true)
	await await_idle_frame()
	await _reach_play_turn()


func after_test() -> void:
	_release()
	Saves.run_service().delete()


func test_dragging_across_cards_selects_each_one() -> void:
	var views: Array[CardView] = _views()
	var ids: Array[int] = [views[0].card_id, views[1].card_id, views[2].card_id]
	await _drag([views[0], views[1], views[2]])
	assert_array(_app.hand.selected_ids()).contains_exactly_in_any_order(ids)
	_assert_actions_follow_the_model()


func test_dragging_from_a_selected_card_clears_the_run() -> void:
	var views: Array[CardView] = _views()
	await _drag([views[0], views[1], views[2]])
	await _drag([views[0], views[1]])
	assert_array(_app.hand.selected_ids()).contains_exactly([views[2].card_id])


func test_moving_without_the_button_held_selects_nothing_more() -> void:
	var views: Array[CardView] = _views()
	await _drag([views[0]])
	_move(views[1])
	_move(views[2])
	await await_idle_frame()
	assert_array(_app.hand.selected_ids()).contains_exactly([views[0].card_id])


func test_two_unmatched_cards_disable_play_with_a_reason() -> void:
	var pair: Array[CardView] = _unmatched_neighbours()
	assert_int(pair.size()).is_equal(2)
	await _drag(pair)
	assert_bool(_app.hand.can_play()).is_false()
	assert_bool(_table.actions().play.disabled).is_true()
	assert_str(_table.actions().reading.text).starts_with(tr(_app.hand.label_key()))
	assert_str(_table.actions().reading.text).is_not_empty()


func test_one_clicked_card_reads_as_a_single() -> void:
	var views: Array[CardView] = _views()
	await _drag([views[0]])
	assert_array(_app.hand.selected_ids()).contains_exactly([views[0].card_id])
	_assert_actions_follow_the_model()


func _assert_actions_follow_the_model() -> void:
	assert_bool(_table.actions().play.disabled).is_equal(not _app.hand.can_play())
	assert_str(_table.actions().reading.text).starts_with(tr(_app.hand.label_key()))


## Plays bids and need declarations by button until it is the player's turn to play.
func _reach_play_turn() -> void:
	for _step: int in 200:
		_table.skip_events()
		await await_idle_frame()
		match _app.controller.awaiting():
			RunController.AWAIT_PLAY:
				_table.skip_events()
				await await_idle_frame()
				return
			RunController.AWAIT_BID:
				_table.actions().decline.pressed.emit()
			RunController.AWAIT_NEED:
				_table.need_panel().declared.emit(ControllerScript.NEED)


## The hand's views in fan order, left to right.
func _views() -> Array[CardView]:
	var hand_view: HandView = _table.get("_hand_view")
	var views: Array[CardView] = []
	for child: Node in hand_view.get_children():
		var view: CardView = child as CardView
		if view != null and view.visible:
			views.append(view)
	return views


## Two neighbouring cards of different ranks that are not the rocket.
func _unmatched_neighbours() -> Array[CardView]:
	var views: Array[CardView] = _views()
	var cards: Dictionary[int, CardInstance] = {}
	for card: CardInstance in _app.hand.cards():
		cards[card.id()] = card
	for index: int in views.size() - 1:
		var left: CardInstance = cards[views[index].card_id]
		var right: CardInstance = cards[views[index + 1].card_id]
		var rocket: bool = mini(left.base_rank(), right.base_rank()) >= Ranks.SMALL_JOKER
		if left.base_rank() != right.base_rank() and not rocket:
			return [views[index], views[index + 1]]
	return []


## Presses on the first view, moves across the rest with the button held, and releases.
func _drag(views: Array[CardView]) -> void:
	_move(views[0])
	_button(views[0], true)
	for view: CardView in views.slice(1):
		_move(view, true)
	_button(views[-1], false)
	await await_idle_frame()


func _move(view: CardView, held: bool = false) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = _grip(view)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(motion)
	Input.flush_buffered_events()


func _button(view: CardView, down: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.position = _grip(view)
	click.global_position = click.position
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(click)
	Input.flush_buffered_events()


func _release() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = false
		Input.parse_input_event(click)
		Input.flush_buffered_events()


## A window point on the view's uncovered strip. The window may be smaller than the
## 1920x1080 canvas (headless runs use 64x64), so the root's stretch transform applies.
func _grip(view: CardView) -> Vector2:
	return get_tree().root.get_final_transform() * (view.get_global_transform_with_canvas() * GRIP)

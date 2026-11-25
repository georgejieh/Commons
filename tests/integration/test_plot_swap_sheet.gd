extends GdUnitTestSuite
## The plot swap is a sheet over the table (ADR 0038). It opens once the table's queue is
## empty and nothing at the table plays while it is open; answering it plays the round on
## at the same table, the villager landlord's first play shown, not replayed. It shows
## real cards in rank order with their marks; a click on each side trades, so does a drag,
## Undo takes a pair back, a pick past the round's swaps is refused where the count is,
## the keys move a cursor and press, and with reduced motion the cards stand at once.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_plot_swap_sheet/run.json"
const PLOT_CARDS: int = 3

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## Stocks the plot, a Model card and a stamped one among it, and plays the table up to the
## swap, declining every bid, so a villager is landlord.
func _to_swap() -> TableScreen:
	var state: RunState = _loop().state
	for index: int in PLOT_CARDS:
		var card: CardInstance = CardInstance.new(
			CardInstance.FIRST_PLOT_ID + index, Ranks.QUEEN - index, index, CardInstance.Origin.PLOT
		)
		if index == 0:
			CardMarks.enhance(state, card, CardInstance.MODEL)
		if index == 1:
			CardMarks.stamp(state, card, RunLoop.PLAYER)
		state.inventory.plot.append(card)
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var sheet: PlotSwapSheet = table.get("_swap_sheet")
	for _turn: int in 60:
		if sheet.is_open():
			break
		table.skip_events()
		if _app.controller.awaiting() == RunController.AWAIT_BID:
			table.actions().decline.pressed.emit()
		await await_idle_frame()
	assert_bool(sheet.is_open()).is_true()
	return table


func _sheet(table: TableScreen) -> PlotSwapSheet:
	return table.get("_swap_sheet")


func test_nothing_plays_while_the_sheet_is_open_and_the_round_plays_on_after() -> void:
	var table: TableScreen = await _to_swap()
	var player: EventPlayer = table.get("_player")
	var landlord: int = _loop().state.landlord_seat
	assert_bool(player.is_idle()).is_true()
	var played: Array[RunEvent] = []
	player.played.connect(func(event: RunEvent) -> void: played.append(event))
	for _frame: int in 20:
		await await_idle_frame()
	assert_array(played).is_empty()
	assert_int(_app.controller.awaiting()).is_equal(RunController.AWAIT_SWAP)
	for event: RoundEvent in _loop().round_state().events():
		assert_int(event.type).is_not_equal(RoundEvent.Type.PLAYED)
	_sheet(table).keep_button().pressed.emit()
	assert_bool(_sheet(table).is_open()).is_false()
	# The same table plays the answer's events through its own queue.
	assert_object(_app.switcher.current()).is_same(table)
	table.skip_events()
	var first: RoundEvent = null
	for event: RunEvent in played:
		if event.round_event != null and event.round_event.type == RoundEvent.Type.PLAYED:
			first = event.round_event
			break
	if landlord != RunLoop.PLAYER:
		assert_object(first).is_not_null()
		assert_int(first.seat).is_equal(landlord)


func test_the_board_shows_real_cards_in_rank_order_with_their_marks() -> void:
	var table: TableScreen = await _to_swap()
	var board: SwapBoard = _sheet(table).board()
	var hand: Array[int] = board.place_ids(SwapBoard.Place.HAND)
	assert_int(hand.size()).is_equal(_app.controller.player_cards().size())
	for index: int in range(1, hand.size()):
		var before: CardInstance = _card(hand[index - 1])
		var after: CardInstance = _card(hand[index])
		assert_bool(_app.hand.rank_value(before) <= _app.hand.rank_value(after)).is_true()
	var plot: Array[int] = board.place_ids(SwapBoard.Place.PLOT)
	assert_int(plot.size()).is_equal(PLOT_CARDS)
	var shown: String = board.view_of(CardInstance.FIRST_PLOT_ID).shown_enhancement()
	assert_str(shown).is_equal(CardInstance.MODEL)
	assert_bool(board.view_of(CardInstance.FIRST_PLOT_ID + 1).shows_stamp()).is_true()
	for card_id: int in hand + plot:
		assert_vector(board.view_of(card_id).size).is_equal(SwapFit.CARD)
		assert_bool(board.view_of(card_id).visible).is_true()


func test_a_click_on_each_side_trades_and_undo_takes_it_back() -> void:
	var table: TableScreen = await _to_swap()
	var sheet: PlotSwapSheet = _sheet(table)
	var board: SwapBoard = sheet.board()
	var given: int = board.place_ids(SwapBoard.Place.HAND)[0]
	var taken: int = CardInstance.FIRST_PLOT_ID + 2
	assert_bool(sheet.swap_button().disabled).is_true()
	board.press(given)
	assert_int(board.trade.picked).is_equal(given)
	board.press(taken)
	assert_int(board.trade.pairs()).is_equal(1)
	assert_array(board.place_ids(SwapBoard.Place.HAND)).contains([taken])
	assert_array(board.place_ids(SwapBoard.Place.OUT)).is_equal([given])
	assert_array(board.place_ids(SwapBoard.Place.PLOT)).not_contains([taken])
	assert_int(board.tags().filter(func(tag: Label) -> bool: return tag.visible).size()).is_equal(3)
	var count: Label = sheet.get("_count")
	assert_str(count.text).is_equal(tr("plot.left.count").format({"left": 0, "limit": 1}))
	assert_bool(sheet.swap_button().disabled).is_false()
	# No swap is left, so a fresh pick is refused, and the sheet says why.
	var other: int = board.place_ids(SwapBoard.Place.HAND)[1]
	assert_int(board.press(other)).is_equal(PlotTrade.Reason.NO_SWAPS_LEFT)
	var status: Label = sheet.get("_status")
	assert_str(status.text).is_equal(tr("plot.none_left"))
	assert_int(sheet.undo_buttons().size()).is_equal(1)
	sheet.undo_buttons()[0].pressed.emit()
	assert_int(board.trade.pairs()).is_equal(0)
	assert_array(board.place_ids(SwapBoard.Place.PLOT)).contains([taken])
	# Traded again and sent: the plot card is in the hand, and the plot is as it was.
	board.press(taken)
	board.press(given)
	var plot_before: int = _loop().state.inventory.plot.size()
	sheet.swap_button().pressed.emit()
	assert_bool(sheet.is_open()).is_false()
	var held: Array[int] = []
	for card: CardInstance in _app.controller.player_cards():
		held.append(card.id())
	assert_array(held).contains([taken])
	assert_array(held).not_contains([given])
	assert_int(_loop().state.inventory.plot.size()).is_equal(plot_before)


func test_dragging_a_plot_card_onto_a_hand_card_trades_them() -> void:
	var table: TableScreen = await _to_swap()
	var board: SwapBoard = _sheet(table).board()
	var target: int = board.place_ids(SwapBoard.Place.HAND)[3]
	var dragged: int = CardInstance.FIRST_PLOT_ID
	var from: Vector2 = board.card_rect(dragged).get_center()
	var to: Vector2 = board.card_rect(target).position + Vector2(8, 60)
	board.call("_gui_input", _button(from, true))
	board.call("_gui_input", _motion(from.lerp(to, 0.5)))
	board.call("_gui_input", _motion(to))
	board.call("_gui_input", _button(to, false))
	assert_int(board.trade.pairs()).is_equal(1)
	assert_array(board.trade.hand_ids).is_equal([target])
	assert_array(board.trade.plot_ids).is_equal([dragged])


func test_keys_move_the_cursor_and_press_and_focus_stays_on_the_sheet() -> void:
	var table: TableScreen = await _to_swap()
	var sheet: PlotSwapSheet = _sheet(table)
	var board: SwapBoard = sheet.board()
	assert_bool(board.has_focus()).is_true()
	var first: int = board.cursor_card()
	board.call("_gui_input", _action("ui_right"))
	assert_int(board.cursor_card()).is_not_equal(first)
	board.call("_gui_input", _action("ui_accept"))
	assert_int(board.trade.picked).is_equal(board.cursor_card())
	# Below the cards is Keep hand while nothing is traded; the buttons lead back up.
	assert_object(board.get_node(board.focus_neighbor_bottom)).is_same(sheet.keep_button())
	var keep: Button = sheet.keep_button()
	assert_object(keep.get_node(keep.focus_neighbor_top)).is_same(board)
	assert_object(keep.get_node(keep.focus_neighbor_bottom)).is_same(keep)


func test_with_reduced_motion_the_cards_stand_at_once() -> void:
	Settings.set_value("reduced_motion", true)
	var table: TableScreen = await _to_swap()
	var board: SwapBoard = _sheet(table).board()
	var given: int = board.place_ids(SwapBoard.Place.HAND)[0]
	board.press(given)
	board.press(CardInstance.FIRST_PLOT_ID)
	for card_id: int in [given, CardInstance.FIRST_PLOT_ID]:
		assert_vector(board.view_of(card_id).position).is_equal(board.card_rect(card_id).position)


func _card(card_id: int) -> CardInstance:
	for card: CardInstance in _app.controller.player_cards():
		if card.id() == card_id:
			return card
	return null


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _action(action: String) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

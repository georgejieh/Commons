extends GdUnitTestSuite
## The plot swap sheet holds the most it can be asked to (ADR 0038): a 20-card landlord
## hand, the round's most swaps and the plot at its largest, as the data sets them, on
## both screens at every text size (ADR 0034). Everything on it is on the screen, its
## three places stand apart in order, every card is inside the paper and the buttons
## clear the cards.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_plot_swap_layout/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const LANDLORD_HAND: int = 20
const SLACK: float = 1.0

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


## The most plot cards and swaps a run can hold, from the data and its upgrades.
func _most_plot() -> int:
	return RunDefaults.PARAMS.plot_capacity + RunDefaults.PLOT_UPGRADES.capacity_max


func _most_swaps() -> int:
	return RunDefaults.PARAMS.swaps_per_round + RunDefaults.PLOT_UPGRADES.swap_max


func _to_swap() -> TableScreen:
	var state: RunState = _loop().state
	for index: int in _most_plot():
		state.inventory.plot.append(
			CardInstance.new(
				CardInstance.FIRST_PLOT_ID + index,
				Ranks.TEN + index % 4,
				index % 4,
				CardInstance.Origin.PLOT
			)
		)
	state.swap_bonus = RunDefaults.PLOT_UPGRADES.swap_max
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	for _turn: int in 60:
		if _sheet(table).is_open():
			break
		table.skip_events()
		if _app.controller.awaiting() == RunController.AWAIT_BID:
			table.actions().decline.pressed.emit()
		await await_idle_frame()
	assert_bool(_sheet(table).is_open()).is_true()
	return table


func _sheet(table: TableScreen) -> PlotSwapSheet:
	return table.get("_swap_sheet")


## Lays the board out with a full landlord hand and the full plot, two pairs traded.
func _fill(table: TableScreen) -> void:
	var hand: Array[CardInstance] = []
	for deck_id: int in LANDLORD_HAND:
		hand.append(Deck.new().card(deck_id * 2 + 1))
	var plot: Array[CardInstance] = _loop().state.inventory.plot
	var sheet: PlotSwapSheet = _sheet(table)
	var board: SwapBoard = sheet.board()
	var no_wild: Array[int] = []
	board.show_cards(hand, plot, _most_swaps(), table.get("_pool"), _app.hand, no_wild)
	for pair: int in _most_swaps():
		board.press(hand[pair].id())
		board.press(plot[pair].id())


func test_a_full_hand_and_plot_fit_on_both_screens_at_every_text_size() -> void:
	assert_int(_most_plot()).is_equal(6)
	assert_int(_most_swaps()).is_equal(2)
	var table: TableScreen = await _to_swap()
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			table = _app.show_screen("table", true)
			await await_idle_frame()
			assert_bool(_sheet(table).is_open()).is_true()
			_fill(table)
			await await_idle_frame()
			await await_idle_frame()
			_check(table, "level %d %s" % [level, screen_size])


func _check(table: TableScreen, where: String) -> void:
	var sheet: PlotSwapSheet = _sheet(table)
	var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
	var paper: Rect2 = sheet.paper().get_global_rect()
	for node: Node in sheet.paper().find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.get_global_rect().size == Vector2.ZERO:
			continue
		var rect: Rect2 = control.get_global_rect()
		(
			assert_bool(screen.encloses(rect))
			. override_failure_message("%s: %s at %s" % [where, control.get_path(), rect])
			. is_true()
		)
	var board: SwapBoard = sheet.board()
	var ends: Array[float] = []
	for place: int in SwapBoard.Place.size():
		var left: float = INF
		var right: float = -INF
		for card_id: int in board.place_ids(place):
			var rect: Rect2 = board.card_rect(card_id)
			rect.position += board.global_position
			(
				assert_bool(paper.grow(SLACK).encloses(rect))
				. override_failure_message("%s: card %d at %s" % [where, card_id, rect])
				. is_true()
			)
			left = minf(left, rect.position.x)
			right = maxf(right, rect.end.x)
		ends.append_array([left, right])
	# Hand, then the cards that sit out, then the plot, each clear of the next.
	(
		assert_bool(ends[1] <= ends[2] and ends[3] <= ends[4])
		. override_failure_message("%s: places %s" % [where, ends])
		. is_true()
	)
	assert_int(board.place_ids(SwapBoard.Place.HAND).size()).is_equal(LANDLORD_HAND)
	var cards: Rect2 = board.get_global_rect()
	for button: Button in [sheet.swap_button(), sheet.keep_button()]:
		assert_bool(screen.encloses(button.get_global_rect())).is_true()
		assert_bool(button.get_global_rect().intersects(cards.grow(-SLACK))).is_false()

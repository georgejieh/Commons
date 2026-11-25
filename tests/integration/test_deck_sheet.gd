extends GdUnitTestSuite
## The deck sheet (ADR 0041): from either shop's Deck button and the table's, it lays out
## all 54 deck cards as real faces in rank order, a rank to a group, and the plot's cards
## after them, each with its marks, and a legend of the marks the run holds. It fits the
## screen at 1920x1080 and 1280x800 at every text size without scrolling at Standard,
## keeps the focus while open, names a card's marks in the slip beside it, and closes on
## Cancel. At the table it opens from the menu, and nothing plays while it is open.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_deck_sheet/run.json"
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]
const SLACK: float = 1.5
const MODEL_CARD: int = 0
const STAMPED_CARD: int = 9
const SURPLUS_CARD: int = 53

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
	return _app.controller.get("_loop")


func _to_the_store() -> StoreScreen:
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	var state: RunState = _loop().state
	CardMarks.enhance(state, CardInstance.from_deck_id(MODEL_CARD), CardInstance.MODEL)
	CardMarks.enhance(state, CardInstance.from_deck_id(SURPLUS_CARD), CardInstance.SURPLUS)
	CardMarks.stamp(state, CardInstance.from_deck_id(STAMPED_CARD), RunLoop.PLAYER)
	_app.controller.reseal_book()
	return _app.show_screen("store", true)


func _deck_button(root: Node) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == tr("deck.open") and button.is_visible_in_tree():
			return button
	return null


func test_the_sheet_shows_every_deck_card_with_its_marks() -> void:
	var store: StoreScreen = _to_the_store()
	await await_idle_frame()
	_deck_button(store).pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = store.get("_deck")
	assert_bool(sheet.is_open()).is_true()
	var board: DeckBoard = sheet.board()
	var plot: int = _app.controller.state_copy().inventory.plot.size()
	assert_int(board.card_ids().size()).is_equal(Deck.SIZE + plot)
	assert_str(board.view_of(MODEL_CARD).shown_enhancement()).is_equal(CardInstance.MODEL)
	assert_str(board.view_of(SURPLUS_CARD).shown_enhancement()).is_equal(CardInstance.SURPLUS)
	assert_bool(board.view_of(STAMPED_CARD).shows_stamp()).is_true()
	# In rank order: every card of a rank before any card of a higher one.
	var last: int = -1
	for card_id: int in board.card_ids().slice(0, Deck.SIZE):
		var rank: int = board.card_of(card_id).base_rank()
		assert_int(rank).is_greater_equal(last)
		last = rank
	# The legend names at least the stamp, Model and Surplus.
	var legend: HBoxContainer = sheet.get("_legend")
	assert_int(legend.get_child_count()).is_greater_equal(3)
	# A hover names the card's marks in the slip beside it.
	board.point_at(MODEL_CARD)
	assert_str(sheet.slip().shown_rule()).is_equal(DeckSheet.marks_text(board.card_of(MODEL_CARD)))
	assert_bool(sheet.slip().shown_rule().contains(tr("keyword.model.name"))).is_true()


func test_the_sheet_fits_both_screens_at_every_text_size() -> void:
	var store: StoreScreen = _to_the_store()
	await await_idle_frame()
	var sheet: DeckSheet = store.get("_deck")
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			await await_idle_frame()
			sheet.open_deck()
			await await_idle_frame()
			await await_idle_frame()
			var label: String = "text %d at %s" % [level, screen_size]
			var screen: Rect2 = get_tree().root.get_visible_rect().grow(SLACK)
			(
				assert_bool(screen.encloses(sheet.paper().get_global_rect()))
				. override_failure_message(label)
				. is_true()
			)
			var scroll: ScrollContainer = sheet.get("_scroll")
			var board: DeckBoard = sheet.board()
			if level == 0:
				# At Standard the cards fit without scrolling.
				(
					assert_float(board.custom_minimum_size.y)
					. override_failure_message(label)
					. is_less_equal(scroll.size.y + SLACK)
				)
			assert_float(board.card_scale()).is_greater_equal(DeckFit.LEAST_SCALE - 0.001)
			assert_float(board.custom_minimum_size.x).override_failure_message(label).is_less_equal(
				scroll.size.x + SLACK
			)
			sheet.close()


func test_the_sheet_keeps_the_focus_and_cancel_closes_it() -> void:
	var store: StoreScreen = _to_the_store()
	await await_idle_frame()
	var sheet: DeckSheet = store.get("_deck")
	sheet.open_deck()
	await await_idle_frame()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(sheet.board())
	var first: int = sheet.board().cursor_card()
	await _tap("ui_right")
	assert_int(sheet.board().cursor_card()).is_not_equal(first)
	await _tap("ui_down")
	var owner: Control = get_viewport().gui_get_focus_owner()
	assert_bool(owner == sheet.board() or sheet.is_ancestor_of(owner)).is_true()
	await _tap("ui_cancel")
	assert_bool(sheet.is_open()).is_false()


## Presses and lets go of an action, so no later test finds it held.
func _tap(action: String) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await await_idle_frame()


func test_the_table_opens_it_from_its_menu_and_waits() -> void:
	var table: Node = _app.show_screen("table", true)
	await await_idle_frame()
	var menu: PauseMenu = table.get("_pause")
	table.call("_open_pause")
	var deck: Button = _deck_button(menu)
	assert_object(deck).is_not_null()
	deck.pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = table.get("_deck")
	assert_bool(sheet.is_open()).is_true()
	assert_bool(menu.visible).is_false()
	var player: EventPlayer = table.get("_player")
	assert_bool(player.is_processing()).is_false()
	sheet.close()
	assert_bool(player.is_processing()).is_true()

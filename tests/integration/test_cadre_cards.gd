extends GdUnitTestSuite
## A Cadre card shows its art alone; its name and rules are in its tooltip, on the
## store counter and on the table's notice board.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_cadre_cards/run.json"

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	# Play the first Set by script so the store has stock.
	var controller: RunController = _app.controller
	var driver: ControllerScript = ControllerScript.new()
	while driver.act(controller):
		pass
	if controller.awaiting() == RunController.AWAIT_SET_OVER:
		controller.finish_set()


func after_test() -> void:
	Saves.run_service().delete()


func test_store_cards_show_art_and_put_name_and_rules_in_the_tooltip() -> void:
	var store: Control = _app.show_screen("store")
	await await_idle_frame()
	var counter: HBoxContainer = store.get("_counter")
	var stock: Array[String] = _app.controller.store_stock()
	assert_int(stock.size()).is_greater(0)
	assert_int(counter.get_child_count()).is_equal(stock.size())
	for slot: int in stock.size():
		var panel: Control = counter.get_child(slot) as Control
		var tip: String = ScreenKit.cadre_tip(_app.controller, stock[slot])
		assert_str(panel.tooltip_text).is_equal(tip)
		assert_str(tip).contains(tr("modifier.%s.name" % stock[slot]))
		assert_str(tip).contains(_app.controller.modifier_text(stock[slot]))
		assert_int(_labels(panel).size()).is_equal(0)


func test_focusing_a_buy_button_reads_the_cadre_out() -> void:
	var store: Control = _app.show_screen("store")
	await await_idle_frame()
	var counter: HBoxContainer = store.get("_counter")
	var idle: Label = store.get("_reading")
	assert_bool(idle.visible).is_false()
	var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	buy.focus_entered.emit()
	var reading: Label = store.get("_reading")
	assert_bool(reading.visible).is_true()
	var first: String = _app.controller.store_stock()[0]
	assert_str(reading.text).is_equal(ScreenKit.cadre_tip(_app.controller, first))


func test_the_notice_board_cards_carry_the_tooltip() -> void:
	var stock: Array[String] = _app.controller.store_stock()
	var slot: int = range(stock.size()).filter(_app.controller.can_buy).front()
	var first: String = stock[slot]
	_app.controller.buy(slot)
	var board: NoticeBoard = auto_free(NoticeBoard.new())
	add_child(board)
	board.setup(3)
	board.show_cadres(_app.controller)
	var cards: Array[Control] = board.get("_cards")
	assert_str(cards[0].tooltip_text).is_equal(ScreenKit.cadre_tip(_app.controller, first))
	assert_str(cards[1].tooltip_text).is_empty()
	assert_int(_labels(board).size()).is_equal(0)


func _labels(node: Node) -> Array[Node]:
	return node.find_children("*", "Label", true, false)

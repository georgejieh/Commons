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
		var rule: String = _app.controller.modifier_text(stock[slot])
		assert_str(tip.replace("\n", " ")).contains(rule)
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
	var cards: Array[TipHost] = board.get("_cards")
	assert_str(cards[0].tooltip_text).contains(tr("modifier.%s.name" % first))
	assert_str(cards[0].tip_rule()).is_equal(ScreenKit.rule_text(_app.controller, first))
	assert_str(cards[1].tooltip_text).is_empty()
	assert_int(_labels(board).size()).is_equal(0)


func _labels(node: Node) -> Array[Node]:
	return node.find_children("*", "Label", true, false)


func test_buying_seals_the_card_and_pins_it_to_your_board() -> void:
	var store: StoreScreen = _app.show_screen("store")
	await await_idle_frame()
	var stock: Array[String] = _app.controller.store_stock()
	var slot: int = range(stock.size()).filter(_app.controller.can_buy).front()
	var bought: String = stock[slot]
	var held: int = _app.controller.state_copy().inventory.cadres.size()
	var counter: HBoxContainer = store.get("_counter")
	var buy: Button = counter.get_child(slot).find_children("*", "Button", true, false)[0]
	buy.pressed.emit()
	# The purchase is made at once; only its show takes time.
	assert_array(_app.controller.state_copy().inventory.cadres).contains([bought])
	assert_bool(store.is_buying()).is_true()
	var seal: InkSeal = store.get("_seal")
	assert_bool(seal.visible).is_true()
	assert_str(seal.word()).is_equal(tr("store.approved").to_upper())
	await await_millis(int((StoreScreen.SEAL_HOLD + StoreScreen.PIN_TIME) * 1000.0) + 300)
	assert_bool(store.is_buying()).is_false()
	assert_bool(seal.visible).is_false()
	var board: NoticeBoard = store.get("_board")
	var cards: Array[TipHost] = board.get("_cards")
	assert_str(cards[held].tip_rule()).is_equal(ScreenKit.rule_text(_app.controller, bought))


func test_the_black_market_sells_private_cadres_and_counts_the_resentment() -> void:
	# Coupons enough for the market's prices, handed out behind the controller.
	var loop: RunLoop = _app.controller.get("_loop")
	loop.state.coupons = 100
	var market: StoreScreen = _app.show_screen("black_market")
	await await_idle_frame()
	assert_bool(market.market).is_true()
	var stock: Array[String] = _app.controller.desk(true).stock()
	assert_int(stock.size()).is_greater(0)
	var before: int = _app.controller.state_copy().resentment
	var counter: HBoxContainer = market.get("_counter")
	var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	buy.pressed.emit()
	var state: RunState = _app.controller.state_copy()
	assert_array(state.inventory.cadres).contains([stock[0]])
	assert_int(state.resentment).is_equal(before + _app.controller.purchase_resentment())
	var seal: InkSeal = market.get("_seal")
	assert_str(seal.word()).is_equal(tr("market.paid").to_upper())
	await await_millis(int((StoreScreen.SEAL_HOLD + StoreScreen.PIN_TIME) * 1000.0) + 300)
	# The plot upgrades are on the counter too, and each is a private purchase.
	var tickets: HBoxContainer = market.get("_upgrades")
	assert_int(tickets.get_child_count()).is_equal(PlotUpgrades.KINDS.size())
	var enlarge: Button = tickets.get_child(0)
	enlarge.pressed.emit()
	var after: RunState = _app.controller.state_copy()
	assert_int(after.plot_capacity_bonus).is_equal(1)
	assert_int(after.resentment).is_equal(before + 2 * _app.controller.purchase_resentment())

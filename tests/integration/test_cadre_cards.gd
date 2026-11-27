extends GdUnitTestSuite
## On the store counter a Cadre card prints its art, or the empty frame for it, its name
## and its full rules, and its Buy button carries the tooltip; on the table's notice board
## a card shows its art and keeps its name and rules in its tooltip.

const SEED: int = 4301

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
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


func test_store_cards_print_name_and_rules_and_buy_shows_no_plain_tooltip() -> void:
	var store: StoreScreen = _app.show_screen(App.STORE)
	await await_idle_frame()
	var cadres: CadreCounter = store.cadres
	var counter: HBoxContainer = cadres.row
	var stock: Array[String] = _app.controller.store.store_stock()
	assert_int(stock.size()).is_greater(0)
	assert_int(counter.get_child_count()).is_equal(stock.size())
	for slot: int in stock.size():
		var panel: Control = counter.get_child(slot) as Control
		var buy: Button = panel.find_children("*", "Button", true, false)[0]
		assert_str(buy.tooltip_text).is_empty()
		var title: String = tr("modifier.%s.name" % stock[slot])
		# The name is printed once, and the full rules under it.
		var names: Array[Node] = _labels(panel).filter(
			func(label: Node) -> bool: return (label as Label).text == title
		)
		assert_int(names.size()).is_equal(1)
		var rules: KeywordText = panel.find_children("*", "KeywordText", true, false)[0]
		var rule: String = _app.controller.texts.modifier_text(stock[slot])
		assert_str(rules.get_parsed_text()).contains(rule)
		var bare: bool = not ScreenKit.ART.has_cadre(stock[slot])
		assert_int(panel.find_children("*", "ArtFrame", true, false).size()).is_equal(
			1 if bare else 0
		)


func test_focusing_a_buy_button_reads_the_cadre_out() -> void:
	var store: StoreScreen = _app.show_screen(App.STORE)
	await await_idle_frame()
	var cadres: CadreCounter = store.cadres
	var counter: HBoxContainer = cadres.row
	var slip: DetailSlip = store.slip
	assert_bool(slip.visible).is_false()
	var card: Control = counter.get_child(0)
	var buy: Button = card.find_children("*", "Button", true, false)[0]
	buy.focus_entered.emit()
	await await_idle_frame()
	# The shared slip reads it out, under the card and clear of it.
	assert_bool(slip.visible).is_true()
	var first: String = _app.controller.store.store_stock()[0]
	assert_str(slip.shown_rule()).is_equal(ScreenKit.rule_text(_app.controller, first))
	assert_bool(slip.get_global_rect().intersects(card.get_global_rect())).is_false()
	buy.focus_exited.emit()
	assert_bool(slip.visible).is_false()


func test_the_notice_board_cards_carry_the_tooltip() -> void:
	var stock: Array[String] = _app.controller.store.store_stock()
	var slot: int = range(stock.size()).filter(_app.controller.store.can_buy).front()
	var first: String = stock[slot]
	_app.controller.buy(slot)
	var board: NoticeBoard = auto_free(NoticeBoard.new())
	add_child(board)
	board.setup(3)
	board.show_cadres(_app.controller)
	var cards: Array[TipHost] = board.cards
	assert_str(cards[0].tooltip_text).contains(tr("modifier.%s.name" % first))
	assert_str(cards[0].tip_rule()).is_equal(ScreenKit.rule_text(_app.controller, first))
	assert_str(cards[1].tooltip_text).is_empty()
	assert_int(_labels(board).size()).is_equal(0)


func _labels(node: Node) -> Array[Node]:
	return node.find_children("*", "Label", true, false)


func test_buying_seals_the_card_and_pins_it_to_your_board() -> void:
	var store: StoreScreen = _app.show_screen(App.STORE)
	await await_idle_frame()
	var stock: Array[String] = _app.controller.store.store_stock()
	var slot: int = range(stock.size()).filter(_app.controller.store.can_buy).front()
	var bought: String = stock[slot]
	var held: int = _app.controller.state_copy().inventory.cadres.size()
	var cadres: CadreCounter = store.cadres
	var counter: HBoxContainer = cadres.row
	var buy: Button = counter.get_child(slot).find_children("*", "Button", true, false)[0]
	buy.pressed.emit()
	# The purchase is made at once; only its show takes time.
	assert_array(_app.controller.state_copy().inventory.cadres).contains([bought])
	assert_bool(store.cadres.is_buying()).is_true()
	var seal: InkSeal = cadres.seal
	assert_bool(seal.visible).is_true()
	assert_str(seal.word()).is_equal(tr("store.approved").to_upper())
	await TestWait.until(self, func() -> bool: return not cadres.is_buying(), "the seal and pin")
	assert_bool(store.cadres.is_buying()).is_false()
	assert_bool(seal.visible).is_false()
	var board: NoticeBoard = store.board
	var cards: Array[TipHost] = board.cards
	assert_str(cards[held].tip_rule()).is_equal(ScreenKit.rule_text(_app.controller, bought))


func test_the_black_market_sells_private_cadres_and_counts_the_resentment() -> void:
	# Coupons enough for the market's prices, handed out behind the controller.
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.coupons = 100
	_app.controller.reseal_book()
	var market: StoreScreen = _app.show_screen(App.BLACK_MARKET)
	await await_idle_frame()
	assert_bool(market.market).is_true()
	var stock: Array[String] = _app.controller.store.desk(true).stock()
	assert_int(stock.size()).is_greater(0)
	var was: int = _app.controller.state_copy().resentment
	var market_cadres: CadreCounter = market.cadres
	var counter: HBoxContainer = market_cadres.row
	var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	buy.pressed.emit()
	var state: RunState = _app.controller.state_copy()
	assert_array(state.inventory.cadres).contains([stock[0]])
	assert_int(state.resentment).is_equal(was + _app.controller.figures.purchase_resentment())
	var seal: InkSeal = market_cadres.seal
	assert_str(seal.word()).is_equal(tr("market.paid").to_upper())
	await TestWait.until(
		self, func() -> bool: return not market_cadres.is_buying(), "the seal and pin"
	)
	# The plot upgrades are on the counter too, and each is a private purchase.
	var market_goods: MarketGoods = market.goods
	var tickets: HBoxContainer = market_goods.upgrades
	assert_int(tickets.get_child_count()).is_equal(PlotUpgrades.KINDS.size())
	var enlarge: Button = tickets.get_child(0)
	enlarge.pressed.emit()
	var now: RunState = _app.controller.state_copy()
	assert_int(now.plot_capacity_bonus).is_equal(1)
	assert_int(now.resentment).is_equal(was + 2 * _app.controller.figures.purchase_resentment())


func test_a_reroll_waits_for_a_purchase_being_acted_out() -> void:
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.coupons = 100
	_app.controller.reseal_book()
	var store: StoreScreen = _app.show_screen(App.STORE)
	await await_idle_frame()
	var cadres: CadreCounter = store.cadres
	var counter: HBoxContainer = cadres.row
	var buy: Button = counter.get_child(0).find_children("*", "Button", true, false)[0]
	buy.pressed.emit()
	assert_bool(store.cadres.is_buying()).is_true()
	var stock: Array[String] = _app.controller.store.store_stock()
	var coupons: int = _app.controller.state_copy().coupons
	var reroll: Button = store.reroll
	reroll.pressed.emit()
	assert_array(_app.controller.store.store_stock()).is_equal(stock)
	assert_int(_app.controller.state_copy().coupons).is_equal(coupons)
	await TestWait.until(self, func() -> bool: return not cadres.is_buying(), "the seal and pin")
	assert_bool(store.cadres.is_buying()).is_false()


func test_the_collection_lists_the_cadres_of_both_shops() -> void:
	var collection: Control = _app.show_screen(App.COLLECTION)
	await await_idle_frame()
	var flows: Array[Node] = collection.find_children("*", "HFlowContainer", true, false)
	var cadres: int = flows[0].get_child_count() + flows[1].get_child_count()
	assert_int(cadres).is_equal(RunLoop.all_cadres().size())

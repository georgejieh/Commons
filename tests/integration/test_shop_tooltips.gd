extends GdUnitTestSuite
## On both shop pages one paper explains everything: the shared slip. No control there
## shows the engine's plain tooltip; a Cadre held on the board or a Campaign in hand keeps
## its TipHost, whose tooltip is drawn as the same slip. Resting the pointer on a Cadre's
## Buy button, a Directive's document or its button, an upgrade ticket or the Deck button
## opens the slip over its own paper, in the words its tooltip had. The deck sheet's
## legend, opened over either shop or the table, explains each mark in the sheet's slip.

const SEED: int = 4242
const MODEL_CARD: int = 0
const STAMPED_CARD: int = 9
const SURPLUS_CARD: int = 53

var _app: App


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.coupons = 60
	_app.controller.reseal_book()
	assert_int(_app.controller.buy(0)).is_equal(RunController.OK)


func after_test() -> void:
	Saves.run_service().delete()


func test_no_control_on_either_shop_page_shows_a_plain_tooltip() -> void:
	for screen_id: String in [ScreenId.STORE, ScreenId.BLACK_MARKET]:
		var store: StoreScreen = _app.show_screen(screen_id, true)
		await await_idle_frame()
		var plain: PackedStringArray = []
		for node: Node in store.find_children("*", "Control", true, false):
			var control: Control = node as Control
			if not control.tooltip_text.is_empty() and not control is TipHost:
				plain.append("%s %s: %s" % [screen_id, control.get_path(), control.tooltip_text])
		assert_array(plain).override_failure_message("\n".join(plain)).is_empty()


func test_the_state_stores_buttons_and_documents_open_the_slip() -> void:
	var store: StoreScreen = _app.show_screen(ScreenId.STORE, true)
	await await_idle_frame()
	var cadres: CadreCounter = store.cadres
	# The first place was bought before the test, and a sold place has no button.
	var card: Control = cadres.row.get_child(1)
	var buy: Button = card.find_children("*", "Button", true, false)[0]
	await _point_at(buy)
	assert_object(store.slip.anchor()).is_same(card)
	var second: String = _app.controller.store.store_stock()[1]
	assert_str(store.slip.shown_rule()).starts_with(ScreenKit.rule_text(_app.controller, second))
	var issue: Button = store.directives.find_children("*", "Button", true, false)[0]
	await _point_at(issue)
	var document: Control = store.slip.anchor()
	assert_bool(document != issue and document.is_ancestor_of(issue)).is_true()
	await _point_at(_deck_button(store))
	assert_object(store.slip.anchor()).is_same(_deck_button(store))
	assert_str(store.slip.shown_rule()).is_equal(tr("deck.open_tip"))


func test_the_black_markets_upgrade_tickets_open_the_slip() -> void:
	var market: StoreScreen = _app.show_screen(ScreenId.BLACK_MARKET, true)
	await await_idle_frame()
	var goods: MarketGoods = market.goods
	var kinds: PackedStringArray = _app.controller.store.desk(true).upgrade_kinds()
	assert_int(goods.upgrades.get_child_count()).is_equal(kinds.size())
	for index: int in kinds.size():
		var ticket: Button = goods.upgrades.get_child(index)
		await _point_at(ticket)
		assert_object(market.slip.anchor()).is_same(ticket)
		var tip: String = tr("market.upgrade.%s.tip" % kinds[index])
		assert_str(market.slip.shown_rule()).is_equal(tip)


func test_the_deck_sheets_legend_opens_its_slip_over_both_shops() -> void:
	_mark_the_deck()
	for screen_id: String in [ScreenId.STORE, ScreenId.BLACK_MARKET]:
		var store: StoreScreen = _app.show_screen(screen_id, true)
		await await_idle_frame()
		store.deck.open_deck()
		await await_idle_frame()
		await _check_legend(store.deck)
		store.deck.close()


func test_the_deck_sheets_legend_opens_its_slip_over_the_table() -> void:
	_mark_the_deck()
	assert_int(_app.controller.leave_store()).is_equal(RunController.OK)
	var table: TableScreen = _app.show_screen(ScreenId.TABLE, true)
	await await_idle_frame()
	table.deck.open_deck()
	await await_idle_frame()
	await _check_legend(table.deck)


## The stamp, Model and Surplus are in the deck, so the legend has an entry for each.
func _mark_the_deck() -> void:
	var state: RunState = _app.controller.run_loop().state
	CardMarks.enhance(state, Deck.new().card(MODEL_CARD), CardInstance.MODEL)
	CardMarks.enhance(state, Deck.new().card(SURPLUS_CARD), CardInstance.SURPLUS)
	CardMarks.stamp(state, Deck.new().card(STAMPED_CARD), RunLoop.PLAYER)
	_app.controller.reseal_book()


## Each legend entry, pointed at, opens the sheet's slip over itself with its mark's
## meaning, and nothing in the open sheet shows a plain tooltip.
func _check_legend(sheet: DeckSheet) -> void:
	var meanings: Array[String] = []
	for mark: String in [DeckSheet.STAMP] + CardInstance.ENHANCEMENTS:
		meanings.append(Keywords.meaning(mark))
	var shown: Array[String] = []
	for entry: Node in sheet.legend.get_children():
		await _point_at(entry as Control)
		assert_object(sheet.slip().anchor()).is_same(entry)
		assert_array(meanings).contains([sheet.slip().shown_rule()])
		shown.append(sheet.slip().shown_rule())
	for mark: String in [DeckSheet.STAMP, CardInstance.MODEL, CardInstance.SURPLUS]:
		assert_array(shown).contains([Keywords.meaning(mark)])
	for node: Node in sheet.find_children("*", "Control", true, false):
		assert_str((node as Control).tooltip_text).override_failure_message(str(node)).is_empty()


## Moves the pointer onto control's middle, as the player's mouse does.
func _point_at(control: Control) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	var middle: Vector2 = control.get_global_rect().get_center()
	motion.position = control.get_viewport().get_canvas_transform() * middle
	motion.global_position = motion.position
	TestInput.push(self, motion)
	await await_idle_frame()


func _deck_button(store: StoreScreen) -> Button:
	for node: Node in store.find_children("*", "Button", true, false):
		if (node as Button).text == tr("deck.open"):
			return node as Button
	return null

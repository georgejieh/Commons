extends GdUnitTestSuite
## On both shop pages one paper explains everything: the shared slip. No control there
## shows the engine's plain tooltip; a Cadre held on the board or a Campaign in hand keeps
## its TipHost, whose tooltip is drawn as the same slip. Resting the pointer on a Cadre's
## Buy button, a Directive's document or its button, an upgrade ticket or the Deck button
## opens the slip over its own paper, in the words its tooltip had.

const SEED: int = 4242

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
	for screen_id: String in ["store", "black_market"]:
		var store: StoreScreen = _app.show_screen(screen_id, true)
		await await_idle_frame()
		var plain: PackedStringArray = []
		for node: Node in store.find_children("*", "Control", true, false):
			var control: Control = node as Control
			if not control.tooltip_text.is_empty() and not control is TipHost:
				plain.append("%s %s: %s" % [screen_id, control.get_path(), control.tooltip_text])
		assert_array(plain).override_failure_message("\n".join(plain)).is_empty()


func test_the_state_stores_buttons_and_documents_open_the_slip() -> void:
	var store: StoreScreen = _app.show_screen(App.STORE, true)
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
	var market: StoreScreen = _app.show_screen(App.BLACK_MARKET, true)
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

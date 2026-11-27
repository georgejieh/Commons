extends GdUnitTestSuite
## The desks in the shops (ADR 0041): the state store's ticket names the mark it gives this
## visit and its price, the black market's names the stamp; the ticket opens the deck
## sheet to choose, a picked card shows what will change on it, the mark it
## loses included, or why the desk refuses it; the confirm marks it through the controller
## and the ticket says the desk is done until the next visit.

const SEED: int = 4242
const CARD: int = 20

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.coupons = 50
	_app.controller.reseal_book()


func after_test() -> void:
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func test_the_store_desk_marks_the_chosen_card() -> void:
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	var offer: String = _loop().visit.shop.desk.offer
	var other: String = CardInstance.SURPLUS if offer == CardInstance.MODEL else CardInstance.MODEL
	CardMarks.enhance(_loop().state, Deck.new().card(CARD), other)
	var stall: DeskStall = store.desk_stall
	stall.show_offer()
	assert_bool(stall.ticket.is_visible_in_tree()).is_true()
	assert_str(stall.ticket.text).contains(tr("keyword.%s.name" % offer))
	assert_bool(stall.ticket.disabled).is_false()
	stall.ticket.pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = store.deck
	assert_bool(sheet.is_open()).is_true()
	assert_bool(sheet.confirm_button().disabled).is_true()
	sheet.board().press(CARD)
	assert_int(sheet.board().picked).is_equal(CARD)
	# The card loses its other mark, and the sheet says so before it happens.
	assert_str(sheet.status_text()).contains(tr("keyword.%s.name" % other))
	assert_str(sheet.status_text()).contains(tr("keyword.%s.name" % offer))
	assert_bool(sheet.confirm_button().disabled).is_false()
	var coupons: int = _app.controller.state_copy().coupons
	sheet.confirm_button().pressed.emit()
	await await_idle_frame()
	assert_bool(sheet.is_open()).is_false()
	assert_str(_loop().state.card_marks.enhancements[CARD]).is_equal(offer)
	assert_int(_app.controller.state_copy().coupons).is_equal(
		coupons - _loop().visit.shop.desk.price()
	)
	assert_str(stall.ticket.text).is_equal(tr("desk.used"))
	assert_bool(stall.ticket.disabled).is_true()


func test_a_card_the_desk_refuses_says_why_and_cannot_be_confirmed() -> void:
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	CardMarks.enhance(_loop().state, Deck.new().card(CARD), _loop().visit.shop.desk.offer)
	var stall: DeskStall = store.desk_stall
	stall.ticket.pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = store.deck
	sheet.board().press(CARD)
	assert_bool(sheet.confirm_button().disabled).is_true()
	var name: String = CardName.of(sheet.board().card_of(CARD))
	assert_str(sheet.status_text()).contains(name)
	sheet.back_button().pressed.emit()
	assert_bool(sheet.is_open()).is_false()
	assert_bool(_loop().visit.shop.desk.used()).is_false()


func test_the_black_market_desk_stamps_the_card() -> void:
	var market: StoreScreen = _app.show_screen("black_market", true)
	await await_idle_frame()
	var stall: DeskStall = market.desk_stall
	assert_str(stall.ticket.text).is_equal(tr("desk.ticket.stamp").format({"price": 3}))
	stall.ticket.pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = market.deck
	assert_str(sheet.get("_title").text).is_equal(tr("deck.desk.stamp_title"))
	var resentment: int = _app.controller.state_copy().resentment
	sheet.board().press(CARD)
	sheet.confirm_button().pressed.emit()
	await await_idle_frame()
	assert_int(_loop().state.card_marks.stamps[CARD]).is_equal(RunLoop.PLAYER)
	assert_int(_app.controller.state_copy().resentment).is_greater(resentment)

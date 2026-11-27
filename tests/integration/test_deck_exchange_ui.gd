extends GdUnitTestSuite
## The deck exchange on screen (ADR 0042). The state store's stall shows its cards at a
## card's proportions with Buy tickets that give their reasons; a ticket opens the deck
## sheet on the card coming in, a joker is refused, a picked card names both cards before
## the confirm, and Back changes nothing. A Requisition's deck card asks for the card it
## replaces the same way, and backing out leaves the envelope open. The read-only sheet
## tells an exchanged deck from a plain one, keeps a rank with no cards, and its slip
## never covers a rank's name. At the table the Deck key opens the sheet.

const SEED: int = 4242
const WAIT_SECONDS: float = 6.0
## A plain deck's slot of a 3.
const THREE: int = 1

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _loop() -> RunLoop:
	return _app.controller.run_loop()


func _to_the_store(coupons: int = 60) -> StoreScreen:
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()
	_loop().state.coupons = coupons
	_app.controller.reseal_book()
	var store: StoreScreen = _app.show_screen(ScreenId.STORE, true)
	await await_idle_frame()
	await await_idle_frame()
	return store


func _goods(store: StoreScreen) -> DeckGoods:
	return store.deck_goods


func test_the_stall_shows_its_cards_at_a_cards_proportions_with_buy_tickets() -> void:
	var store: StoreScreen = await _to_the_store()
	var stall: DeckStallView = _app.controller.store.deck_stall()
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			store = _app.show_screen(ScreenId.STORE, true)
			await await_idle_frame()
			await await_idle_frame()
			for slot: int in stall.count():
				var view: CardView = _goods(store).card_view(slot)
				var shown: Vector2 = view.get_global_transform().get_scale() * view.size
				(
					assert_float(shown.x / shown.y)
					. override_failure_message("level %d %s: %s" % [level, screen_size, shown])
					. is_equal_approx(SwapFit.CARD.x / SwapFit.CARD.y, 0.01)
				)
				var buy: Button = _goods(store).card_button(slot)
				var price: int = stall.price(slot)
				assert_str(buy.text).is_equal(tr("store.buy").format({"price": price}))
				assert_str(view.shown_enhancement()).is_equal(stall.card(slot).enhancement_id())
	var market: StoreScreen = _app.show_screen(ScreenId.BLACK_MARKET, true)
	assert_object(market.deck_goods).is_null()


func test_a_ticket_says_why_it_cannot_be_bought() -> void:
	var poor: StoreScreen = await _to_the_store(0)
	var stall: DeckStallView = _app.controller.store.deck_stall()
	var buy: Button = _goods(poor).card_button(0)
	assert_bool(buy.disabled).is_true()
	assert_str(buy.text).is_equal(tr("store.buy.poor").format({"price": stall.price(0)}))
	# The rank of the first offer at the most the deck may hold.
	var rank: int = stall.card(0).base_rank()
	var state: RunState = _loop().state
	for slot: int in Deck.SMALL_JOKER_ID:
		if state.deck.rank_counts()[rank] >= stall.most():
			break
		if state.deck.rank_of(slot) != rank:
			state.deck.replace(slot, rank, 0)
	state.coupons = 60
	_app.controller.reseal_book()
	var store: StoreScreen = _app.show_screen(ScreenId.STORE, true)
	await await_idle_frame()
	buy = _goods(store).card_button(0)
	assert_bool(buy.disabled).is_true()
	assert_str(buy.text).is_equal(tr("store.buy.at_most"))


func test_a_ticket_opens_the_sheet_and_back_changes_nothing() -> void:
	var store: StoreScreen = await _to_the_store()
	var stall: DeckStallView = _app.controller.store.deck_stall()
	var coming: CardInstance = stall.card(0)
	var was: Dictionary = _app.controller.state_copy().to_dict()
	_goods(store).card_button(0).pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = store.deck
	assert_bool(sheet.is_open()).is_true()
	assert_bool(sheet.incoming_view().visible).is_true()
	assert_int(sheet.incoming_view().card_id).is_equal(coming.id())
	assert_bool(sheet.confirm_button().disabled).is_true()
	sheet.board().press(Deck.SMALL_JOKER_ID)
	assert_bool(sheet.confirm_button().disabled).is_true()
	assert_str(sheet.status_text()).is_equal(tr("exchange.refused.joker"))
	sheet.board().press(THREE)
	assert_bool(sheet.confirm_button().disabled).is_false()
	var three: String = CardName.of(Deck.new().card(THREE))
	var names: Dictionary[String, Variant] = {"in": ExchangeChoice.card_text(coming), "out": three}
	assert_str(sheet.status_text()).is_equal(tr("exchange.change").format(names))
	sheet.back_button().pressed.emit()
	await await_idle_frame()
	assert_bool(sheet.is_open()).is_false()
	assert_dict(_app.controller.state_copy().to_dict()).is_equal(was)


func test_confirming_puts_the_card_in_the_deck_for_its_price() -> void:
	var store: StoreScreen = await _to_the_store()
	var stall: DeckStallView = _app.controller.store.deck_stall()
	var coming: CardInstance = stall.card(0)
	var coupons: int = _app.controller.state_copy().coupons
	var price: int = stall.price(0)
	_goods(store).card_button(0).pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = store.deck
	sheet.board().press(THREE)
	sheet.confirm_button().pressed.emit()
	await await_idle_frame()
	assert_bool(sheet.is_open()).is_false()
	var state: RunState = _app.controller.state_copy()
	assert_int(state.coupons).is_equal(coupons - price)
	assert_int(state.deck.rank_of(THREE)).is_equal(coming.base_rank())
	assert_int(state.deck.suit_of(THREE)).is_equal(coming.suit())
	assert_str(_goods(store).card_button(0).text).is_equal(tr("store.sold"))
	assert_dict(_loop().record.commands[-1]).is_equal(
		{"type": "deck_card", "slot": 0, "out": THREE}
	)


func test_the_sheet_tells_an_exchanged_deck_from_a_plain_one() -> void:
	var store: StoreScreen = await _to_the_store()
	var state: RunState = _loop().state
	# Every 3 put in as a King: the 3s' group stays, empty, and the Kings' says eight.
	for slot: int in Deck.SIZE:
		if state.deck.rank_of(slot) == Ranks.THREE:
			state.deck.replace(slot, Ranks.KING, slot % Deck.SUITS)
	_app.controller.reseal_book()
	var sheet: DeckSheet = store.deck
	sheet.open_deck()
	await await_idle_frame()
	var names: Array = sheet.board().names
	var king: String = tr(CardView.RANK_KEYS[Ranks.KING])
	var three: String = tr(CardView.RANK_KEYS[Ranks.THREE])
	var kings: Label = names[Ranks.KING]
	var threes: Label = names[Ranks.THREE]
	assert_str(kings.text).is_equal(tr("deck.rank_count").format({"rank": king, "count": 8}))
	assert_str(threes.text).is_equal(tr("deck.rank_count").format({"rank": three, "count": 0}))
	assert_str(sheet.status_text()).contains(tr("deck.exchanges").format({"count": 4}))
	sheet.board().point_at(THREE)
	var plain: String = CardName.of(Deck.new().card(THREE))
	assert_str(sheet.slip().shown_rule()).contains(plain)
	# The cursor crosses the row with the empty group and never lands on nothing.
	sheet.board().point_at(sheet.board().card_ids()[0])
	for _step: int in 6:
		var down: InputEventAction = InputEventAction.new()
		down.action = "ui_down"
		down.pressed = true
		sheet.board().grab_focus()
		TestInput.push(self, down)
		assert_int(sheet.board().cursor_card()).is_not_equal(DeckBoard.NONE)
	sheet.close()


func test_the_slip_never_covers_a_ranks_name() -> void:
	var store: StoreScreen = await _to_the_store()
	var sheet: DeckSheet = store.deck
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			await await_idle_frame()
			sheet.open_deck()
			await await_idle_frame()
			await await_idle_frame()
			var names: Array = sheet.board().names
			for card_id: int in sheet.board().card_ids():
				# A card the scroll cuts is pointed at once it is scrolled into sight.
				var view: CardView = sheet.board().view_of(card_id)
				var whole: Rect2 = SlipPlacer.on_screen(view)
				if not SlipPlacer.shown_rect(view).is_equal_approx(whole):
					continue
				sheet.board().point_at(card_id)
				var slip: Rect2 = SlipPlacer.on_screen(sheet.slip())
				for label: Label in names:
					var name_rect: Rect2 = SlipPlacer.shown_rect(label)
					(
						assert_bool(slip.intersects(name_rect))
						. override_failure_message(
							(
								"level %d %s card %d: slip %s on %s"
								% [level, screen_size, card_id, slip, label.text]
							)
						)
						. is_false()
					)
			sheet.close()


func test_a_requisitions_deck_card_asks_for_the_card_it_replaces() -> void:
	var store: StoreScreen = await _to_the_store()
	var stock: Array[String] = ["deck_envelope"]
	_loop().visit.shop.envelopes.stock_with(stock)
	store.refresh()
	await await_idle_frame()
	var stall: EnvelopeStall = store.envelope_stall
	Settings.set_value("reduced_motion", true)
	stall.panel(0).buy.pressed.emit()
	var overlay: EnvelopeOverlay = stall.overlay()
	await await_idle_frame()
	var shelf: EnvelopeShelf = _app.controller.store.opened_envelope()
	assert_bool(shelf.is_deck_card(0)).is_true()
	var coming: CardInstance = shelf.card(0)
	overlay.papers()[0].keep.pressed.emit()
	await await_idle_frame()
	var sheet: DeckSheet = store.deck
	assert_bool(sheet.is_open()).is_true()
	assert_int(sheet.incoming_view().card_id).is_equal(coming.id())
	# Back: the envelope stays open at its choice, and the deck as it was.
	sheet.back_button().pressed.emit()
	await await_idle_frame()
	assert_object(_app.controller.store.opened_envelope()).is_not_null()
	assert_array(_app.controller.state_copy().deck.changed_slots()).is_empty()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(overlay.papers()[0].keep)
	overlay.papers()[0].keep.pressed.emit()
	await await_idle_frame()
	sheet.board().press(THREE)
	sheet.confirm_button().pressed.emit()
	await await_idle_frame()
	await await_idle_frame()
	assert_object(_app.controller.store.opened_envelope()).is_null()
	var state: RunState = _app.controller.state_copy()
	assert_int(state.deck.rank_of(THREE)).is_equal(coming.base_rank())
	assert_str(state.card_marks.enhancements.get(THREE, CardInstance.NO_ID)).is_equal(
		coming.enhancement_id()
	)
	var pick: Dictionary = {"type": "envelope_pick", "index": 0, "out": THREE}
	assert_dict(_loop().record.commands[-1]).is_equal(pick)
	Settings.set_value("reduced_motion", false)


func test_the_deck_key_opens_the_sheet_at_the_table() -> void:
	var table: TableScreen = _app.show_screen(ScreenId.TABLE, true)
	await await_idle_frame()
	var press: InputEventAction = InputEventAction.new()
	press.action = "commons_deck"
	press.pressed = true
	get_viewport().push_input(press)
	var release: InputEventAction = InputEventAction.new()
	release.action = "commons_deck"
	get_viewport().push_input(release)
	await await_idle_frame()
	var sheet: DeckSheet = table.deck
	assert_bool(sheet.is_open()).is_true()
	var player: EventPlayer = table.player
	assert_bool(player.is_processing()).is_false()
	sheet.close()
	assert_bool(player.is_processing()).is_true()

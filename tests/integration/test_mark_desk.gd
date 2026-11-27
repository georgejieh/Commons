extends GdUnitTestSuite
## The shops' desks (ADR 0041): each visit the state store's offers one enhancement, drawn
## on a stream of its own, and the black market's stamps a card as the player's, each for
## its price in data under the books' raise, once a visit, on any of the 54 deck cards.
## The mark is saved on the card for the run and put back on it at every deal. A refusal (too
## poor, used, the card already so marked, no such card, away from a shop) changes
## nothing; the black market's use adds a private purchase's Resentment; a save replays a
## use, and a save from before the desks loads.

const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const RICH: int = 1000
const CARD: int = 21


func test_the_desks_prices_live_in_data() -> void:
	assert_int(STORE.desk_price).is_equal(3)
	assert_bool(STORE.desk_stamps).is_false()
	assert_int(MARKET.desk_price).is_equal(3)
	assert_bool(MARKET.desk_stamps).is_true()


func test_the_store_offers_one_enhancement_a_visit_drawn_the_same_on_a_replay() -> void:
	var offers: Dictionary[String, bool] = {}
	for seed_value: int in range(30, 42):
		var loop: RunLoop = RunScript.at_the_shops(self, seed_value, RICH)
		assert_bool(loop.visit.shop.desk.is_open).is_true()
		assert_bool(CardInstance.ENHANCEMENTS.has(loop.visit.shop.desk.offer)).is_true()
		offers[loop.visit.shop.desk.offer] = true
		assert_bool(loop.visit.market.desk.stamps()).is_true()
		var again: RunLoop = RunRecord.resume(
			loop.record.to_dict(), RunScript.bots(), SetConfig.new()
		)
		assert_str(again.visit.shop.desk.offer).is_equal(loop.visit.shop.desk.offer)
	assert_int(offers.size()).is_greater(1)


func test_the_store_desk_marks_a_deck_card_for_the_run() -> void:
	var loop: RunLoop = RunScript.at_the_shops(self, 31, RICH)
	var offer: String = loop.visit.shop.desk.offer
	var coupons: int = loop.state.coupons
	var resentment: int = loop.state.resentment
	assert_int(loop.player_mark_card(CARD)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons - STORE.desk_price)
	assert_int(loop.state.resentment).is_equal(resentment)
	assert_str(loop.state.card_marks.enhancements[CARD]).is_equal(offer)
	var marked: RunEvent = loop.events()[-1]
	assert_int(marked.type).is_equal(RunEvent.Type.DECK_CARD_MARKED)
	assert_int(marked.value).is_equal(CardInstance.mark_value(offer))
	assert_str(marked.text).is_equal(str(CARD))
	# Once a visit: a second card is refused, and changes nothing.
	_refused(loop, CARD + 1, false)
	# A deal builds the deck fresh and puts the saved mark back on the card.
	var dealt: Array[CardInstance] = [Deck.new().card(CARD)]
	loop.state.card_marks.apply(dealt)
	assert_str(dealt[0].enhancement_id()).is_equal(offer)


func test_a_new_mark_replaces_the_old_one() -> void:
	var loop: RunLoop = RunScript.at_the_shops(self, 31, RICH)
	var other: String = CardInstance.MODEL
	if loop.visit.shop.desk.offer == CardInstance.MODEL:
		other = CardInstance.SURPLUS
	CardMarks.enhance(loop.state, Deck.new().card(CARD), other)
	assert_int(loop.player_mark_card(CARD)).is_equal(RunLoop.Reason.OK)
	assert_str(loop.state.card_marks.enhancements[CARD]).is_equal(loop.visit.shop.desk.offer)


func test_the_black_market_stamps_the_card_and_adds_resentment() -> void:
	var loop: RunLoop = RunScript.at_the_shops(self, 33, RICH)
	var resentment: int = loop.state.resentment
	var coupons: int = loop.state.coupons
	assert_int(loop.player_mark_card(CARD, true)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.card_marks.stamps[CARD]).is_equal(RunLoop.PLAYER)
	assert_bool(loop.state.card_marks.enhancements.has(CARD)).is_false()
	assert_int(loop.state.coupons).is_equal(coupons - MARKET.desk_price)
	assert_int(loop.state.resentment).is_equal(resentment + RESENTMENT.private_purchase)
	var marked: Array[RunEvent] = loop.events().filter(
		func(event: RunEvent) -> bool: return event.type == RunEvent.Type.DECK_CARD_MARKED
	)
	assert_int(marked[-1].value).is_zero()
	# The state store's desk is its own: it still marks a card this visit.
	assert_int(loop.player_mark_card(CARD + 1)).is_equal(RunLoop.Reason.OK)


func test_a_refused_use_changes_nothing() -> void:
	var poor: RunLoop = RunScript.at_the_shops(self, 34, STORE.desk_price - 1)
	assert_int(poor.visit.shop.desk.check(CARD, RunLoop.PLAYER)).is_equal(MarkDesk.Reason.TOO_POOR)
	_refused(poor, CARD, false)
	var loop: RunLoop = RunScript.at_the_shops(self, 34, RICH)
	CardMarks.enhance(loop.state, Deck.new().card(CARD), loop.visit.shop.desk.offer)
	CardMarks.stamp(loop.state, Deck.new().card(CARD + 1), RunLoop.PLAYER)
	assert_int(loop.visit.shop.desk.check(CARD, 0)).is_equal(MarkDesk.Reason.ALREADY_MARKED)
	_refused(loop, CARD, false)
	assert_int(loop.visit.market.desk.check(CARD + 1, 0)).is_equal(MarkDesk.Reason.ALREADY_MARKED)
	_refused(loop, CARD + 1, true)
	assert_int(loop.visit.shop.desk.check(Deck.SIZE, 0)).is_equal(MarkDesk.Reason.NO_SUCH_CARD)
	_refused(loop, Deck.SIZE, false)
	_refused(loop, CardInstance.FIRST_PLOT_ID, false)


func test_nothing_is_marked_away_from_the_shops() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(35), RunScript.bots(), SetConfig.new())
	loop.start_set()
	loop.state.coupons = RICH
	_refused(loop, CARD, false)


func test_a_use_replays_from_a_save_and_an_older_save_still_loads() -> void:
	var loop: RunLoop = RunScript.at_the_shops(self, 36, RICH)
	var older: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = older["checkpoint"]
	checkpoint["coupons"] = RICH
	assert_bool(RunRecordCheck.is_valid(older)).is_true()
	assert_object(RunRecord.resume(older, RunScript.bots(), SetConfig.new())).is_not_null()
	assert_int(loop.player_mark_card(CARD)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_mark_card(CARD + 5, true)).is_equal(RunLoop.Reason.OK)
	var record: Dictionary = loop.record.to_dict()
	var saved: Dictionary = record["checkpoint"]
	saved["coupons"] = RICH
	assert_bool(RunRecordCheck.is_valid(record)).is_true()
	var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())
	assert_bool(resumed.visit.shop.desk.used()).is_true()
	assert_bool(resumed.visit.market.desk.used()).is_true()


## A refused use leaves the state and the record as they were.
func _refused(loop: RunLoop, card_id: int, market: bool) -> void:
	var was: Dictionary = loop.state.to_dict()
	var commands: int = loop.record.commands.size()
	assert_int(loop.player_mark_card(card_id, market)).is_not_equal(RunLoop.Reason.OK)
	assert_dict(loop.state.to_dict()).is_equal(was)
	assert_int(loop.record.commands.size()).is_equal(commands)

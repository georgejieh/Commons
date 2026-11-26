extends GdUnitTestSuite
## The deck exchange (ADR 0042): the state store's stall sells cards for the communal deck,
## each taking the place of a deck card the player names for the rest of the run, one in
## and one out. No joker is offered or taken out, a rank at the most copies is never
## offered nor raised past it, a rank may be emptied, and the offers are drawn the same on
## a replay. The deck saves only its changed slots: a save from before the exchange loads
## as a plain deck, and a run with exchanges resumes to the same deck.

const RICH: int = 1000
const STALL: CardStallParams = preload("res://data/run/deck_stall.tres")
const SEEDS: Array[int] = [31, 32, 33, 34, 35, 36]
## Slots of a plain deck: one of its 3s, and one of its 8s.
const THREE: int = 1
const OUT: int = 21
## The ranks a test fills to the most copies.
const FULL: Array[int] = [Ranks.KING, Ranks.ACE, Ranks.TWO]


func _at_the_shops(seed_value: int, coupons: int = RICH) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	# The Set's end is the record's checkpoint, so a replay has the coupons too.
	loop.state.coupons = coupons
	loop.record.checkpoint["coupons"] = coupons
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


func test_the_most_copies_of_a_rank_fits_what_a_count_key_holds() -> void:
	var params: RunParams = RunDefaults.PARAMS
	var plot_most: int = params.plot_capacity + RunDefaults.PLOT_UPGRADES.capacity_max
	assert_int(params.deck_rank_most).is_equal(8)
	assert_int(params.deck_rank_most + plot_most).is_less_equal(CountKey.MAX_COUNT)
	assert_int(params.deck_rank_most).is_greater_equal(4)


func test_the_stall_offers_no_joker_and_draws_the_same_on_a_replay() -> void:
	var marked: int = 0
	for seed_value: int in SEEDS:
		var loop: RunLoop = _at_the_shops(seed_value)
		var offers: CardOffers = loop.visit.deck_stall.offers
		assert_int(offers.count()).is_equal(STALL.offers)
		for slot: int in offers.count():
			assert_int(offers.rank(slot)).is_less(Ranks.SMALL_JOKER)
			assert_int(offers.suit(slot)).is_between(0, Deck.SUITS - 1)
			if offers.enhancement(slot) != CardInstance.NO_ID:
				marked += 1
				assert_bool(CardInstance.ENHANCEMENTS.has(offers.enhancement(slot))).is_true()
		var again: RunLoop = RunRecord.resume(
			loop.record.to_dict(), RunScript.bots(), SetConfig.new()
		)
		for slot: int in offers.count():
			assert_int(again.visit.deck_stall.offers.rank(slot)).is_equal(offers.rank(slot))
			assert_int(again.visit.deck_stall.offers.suit(slot)).is_equal(offers.suit(slot))
			assert_str(again.visit.deck_stall.offers.enhancement(slot)).is_equal(
				offers.enhancement(slot)
			)
	assert_int(marked).is_less(SEEDS.size() * STALL.offers)


func test_a_bought_card_takes_the_named_slot_for_the_run_and_its_marks_go() -> void:
	var loop: RunLoop = _at_the_shops(31)
	var offers: CardOffers = loop.visit.deck_stall.offers
	var rank: int = offers.rank(0)
	var suit: int = offers.suit(0)
	var mark: String = offers.enhancement(0)
	var price: int = offers.price(0)
	CardMarks.stamp(loop.state, loop.state.deck.card(OUT), RunLoop.PLAYER)
	CardMarks.enhance(loop.state, loop.state.deck.card(OUT), CardInstance.SHEAF)
	var coupons: int = loop.state.coupons
	assert_int(loop.player_deck_card(0, OUT)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons - price)
	assert_int(loop.state.deck.rank_of(OUT)).is_equal(rank)
	assert_int(loop.state.deck.suit_of(OUT)).is_equal(suit)
	assert_bool(loop.state.card_marks.stamps.has(OUT)).is_false()
	assert_str(loop.state.card_marks.enhancements.get(OUT, CardInstance.NO_ID)).is_equal(mark)
	assert_int(offers.rank(0)).is_equal(CardOffers.SOLD)
	var cards: Array[CardInstance] = loop.state.deck.cards()
	assert_int(cards.size()).is_equal(Deck.SIZE)
	var plain: Deck = Deck.new()
	var same: bool = plain.rank_of(OUT) == rank and plain.suit_of(OUT) == suit
	assert_array(loop.state.deck.changed_slots()).is_equal([] if same else [OUT])


func test_a_marked_offer_costs_its_mark_more() -> void:
	for seed_value: int in range(1, 200):
		var state: RunState = RunState.new(seed_value)
		var stall: DeckStall = DeckStall.new(state, STALL, RunDefaults.PARAMS)
		stall.open(false)
		for slot: int in stall.offers.count():
			var rank: int = stall.offers.rank(slot)
			var cost: int = STALL.costs[STALL.ranks.find(rank)]
			if stall.offers.enhancement(slot) == CardInstance.NO_ID:
				assert_int(stall.offers.price(slot)).is_equal(cost)
			else:
				assert_int(stall.offers.price(slot)).is_equal(cost + STALL.mark_cost)
				return
	fail("no marked offer in 200 visits")


func test_a_refused_exchange_changes_nothing() -> void:
	var loop: RunLoop = _at_the_shops(32)
	_refused(loop, 0, Deck.SMALL_JOKER_ID, RunShop.Reason.JOKER)
	_refused(loop, 0, Deck.BIG_JOKER_ID, RunShop.Reason.JOKER)
	_refused(loop, 0, Deck.SIZE, RunShop.Reason.NO_SUCH_CARD)
	_refused(loop, 0, CardInstance.FIRST_PLOT_ID, RunShop.Reason.NO_SUCH_CARD)
	_refused(loop, STALL.offers, OUT, RunShop.Reason.NO_SUCH_SLOT)
	assert_int(loop.player_deck_card(0, OUT)).is_equal(RunLoop.Reason.OK)
	_refused(loop, 0, OUT + 1, RunShop.Reason.SOLD_OUT)
	var poor: RunLoop = _at_the_shops(33, 0)
	_refused(poor, 0, OUT, RunShop.Reason.TOO_POOR)


func test_nothing_is_exchanged_away_from_the_shops() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(35), RunScript.bots(), SetConfig.new())
	loop.start_set()
	loop.state.coupons = RICH
	var before: Dictionary = loop.state.to_dict()
	assert_int(loop.player_deck_card(0, OUT)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_dict(loop.state.to_dict()).is_equal(before)


func test_a_rank_at_the_most_is_never_offered_nor_raised_past_it() -> void:
	var run: RunParams = RunDefaults.PARAMS
	for seed_value: int in range(1, 60):
		var state: RunState = RunState.new(seed_value)
		_fill_to_most(state, run.deck_rank_most)
		var stall: DeckStall = DeckStall.new(state, STALL, run)
		stall.open(false)
		for slot: int in stall.offers.count():
			assert_array(FULL).not_contains([stall.offers.rank(slot)])
	var full: RunState = RunState.new(1)
	_fill_to_most(full, run.deck_rank_most)
	for rank: int in FULL:
		assert_int(full.deck.rank_counts()[rank]).is_equal(run.deck_rank_most)
		assert_int(DeckExchange.check_in(full, run, rank)).is_equal(RunShop.Reason.AT_MOST)
	assert_int(DeckExchange.check_in(full, run, Ranks.SIX)).is_equal(RunShop.Reason.OK)


func test_a_rank_may_be_emptied_and_the_deck_holds_54_without_a_third_joker() -> void:
	var state: RunState = RunState.new(1)
	var deck: Deck = state.deck
	for slot: int in Deck.SIZE:
		if deck.rank_of(slot) == Ranks.THREE:
			DeckExchange.apply(state, slot, Ranks.KING, slot % Deck.SUITS, CardInstance.NO_ID)
	var counts: PackedByteArray = deck.rank_counts()
	assert_int(counts[Ranks.THREE]).is_zero()
	assert_int(counts[Ranks.KING]).is_equal(8)
	assert_int(counts[Ranks.SMALL_JOKER] + counts[Ranks.BIG_JOKER]).is_equal(2)
	var total: int = 0
	for count: int in counts:
		total += count
	assert_int(total).is_equal(Deck.SIZE)


func test_the_next_deal_deals_the_exchanged_deck() -> void:
	var loop: RunLoop = _at_the_shops(34)
	var mark: String = loop.visit.deck_stall.offers.enhancement(0)
	var rank: int = loop.visit.deck_stall.offers.rank(0)
	assert_int(loop.player_deck_card(0, THREE)).is_equal(RunLoop.Reason.OK)
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	var held: Array[CardInstance] = _dealt(loop)
	var counts: PackedByteArray = CardSelection.printed_counts(held)
	assert_bool(counts == loop.state.deck.rank_counts()).is_true()
	for card: CardInstance in held:
		if card.id() == THREE:
			assert_int(card.base_rank()).is_equal(rank)
			assert_str(card.enhancement_id()).is_equal(mark)


func test_a_save_before_the_exchange_loads_as_a_plain_deck() -> void:
	var loop: RunLoop = _at_the_shops(36)
	var data: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("deck")
	assert_bool(RunRecordCheck.is_valid(data)).is_false()
	var migrated: Dictionary = RunRecordMigrations.migrate_from_18(data)
	assert_bool(RunRecordCheck.is_valid(migrated)).is_true()
	var resumed: RunLoop = RunRecord.resume(migrated, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.deck.changed_slots()).is_empty()
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(19)


func test_a_run_with_exchanges_resumes_to_the_same_deck_at_every_checkpoint() -> void:
	var loop: RunLoop = _at_the_shops(31)
	assert_int(loop.player_deck_card(0, OUT)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_deck_card(1, THREE)).is_equal(RunLoop.Reason.OK)
	_same_deck(loop)
	# The next Set's start is a checkpoint of its own, with the deck in it.
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	_same_deck(loop)
	var script: RunScript = RunScript.new()
	for _step: int in 40:
		if not script.act(loop):
			break
	_same_deck(loop)


## Resumes the loop's record and finds the same deck and the same marks.
func _same_deck(loop: RunLoop) -> void:
	var record: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
	assert_bool(RunRecordCheck.is_valid(record)).is_true()
	var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_dict(resumed.state.deck.to_dict()).is_equal(loop.state.deck.to_dict())
	assert_dict(resumed.state.card_marks.to_dict()).is_equal(loop.state.card_marks.to_dict())
	assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())


## Every card dealt, across the three seats: those held and those played so far.
func _dealt(loop: RunLoop) -> Array[CardInstance]:
	var script: RunScript = RunScript.new()
	while loop.round_state() == null:
		assert_bool(script.act(loop)).is_true()
	var cards: Array[CardInstance] = []
	for seat: int in Seats.COUNT:
		cards.append_array(loop.round_state().view_for(seat).own_cards)
	for event: RoundEvent in loop.round_state().events():
		if event.type == RoundEvent.Type.PLAYED:
			cards.append_array(event.cards)
	return cards


## Raises the ranks of FULL to most copies, taking 3s, 4s and 5s out to make room.
func _fill_to_most(state: RunState, most: int) -> void:
	var spare: Array[int] = []
	for slot: int in Deck.SIZE:
		if state.deck.rank_of(slot) <= Ranks.FIVE:
			spare.append(slot)
	for rank: int in FULL:
		while state.deck.rank_counts()[rank] < most:
			DeckExchange.apply(state, spare.pop_back(), rank, 0, CardInstance.NO_ID)


## A refused purchase gives its reason and leaves the state and the record as they were.
func _refused(loop: RunLoop, slot: int, out: int, why: RunShop.Reason) -> void:
	assert_int(loop.visit.deck_stall.check_exchange(slot, out)).is_equal(why)
	var before: Dictionary = loop.state.to_dict()
	var commands: int = loop.record.commands.size()
	assert_int(loop.player_deck_card(slot, out)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_dict(loop.state.to_dict()).is_equal(before)
	assert_int(loop.record.commands.size()).is_equal(commands)

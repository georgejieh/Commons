extends GdUnitTestSuite
## A property over random exchanged decks (ADR 0042): every deal, shuffled, biased by
## Planned Allocation, gathered and cut under Unplanned Economy, or dealt by the run, hands
## out exactly the deck's 54 cards, each slot once with the rank and suit the deck holds
## for it, and the deal counts the deck it was dealt from. Mass Line never makes a rank
## wild that the deck holds no card of.

const DECKS: int = 60
const EXCHANGES: int = 30
const RANK_MOST: int = 8


## A deck with up to EXCHANGES random exchanges that keep every rank at or under the most
## and never touch a joker.
func _random_deck(stream: RandomStream) -> RunState:
	var state: RunState = RunState.new(stream.next_int(0, 1 << 30))
	for _exchange: int in EXCHANGES:
		var slot: int = stream.next_int(0, Deck.SMALL_JOKER_ID - 1)
		var rank: int = stream.next_int(Ranks.THREE, Ranks.TWO)
		if state.deck.rank_counts()[rank] >= RANK_MOST:
			continue
		var mark: String = CardInstance.NO_ID
		if stream.next_int(0, 3) == 0:
			mark = CardInstance.ENHANCEMENTS[stream.next_int(0, 3)]
		DeckExchange.apply(state, slot, rank, stream.next_int(0, Deck.SUITS - 1), mark)
	return state


func test_every_deal_hands_out_the_exchanged_deck_once() -> void:
	var stream: RandomStream = RandomStream.new(4242)
	for _deck: int in DECKS:
		var state: RunState = _random_deck(stream)
		var cards: Array[CardInstance] = state.deck.cards()
		state.card_marks.apply(cards)
		var deal_stream: RandomStream = RandomStream.new(stream.next_int(0, 1 << 30))
		_check(state, Dealer.deal(cards, deal_stream))
		var bias: DealBias = DealBias.new(stream.next_int(0, 2), stream.next_int(0, 12), 3.0)
		_check(state, Dealer.deal(cards, deal_stream, bias))
		var dealt: DealResult = Dealer.deal(cards, deal_stream)
		Dealer.rebias(dealt, bias, deal_stream)
		_check(state, dealt)
		var order: Array[int] = []
		order.assign(range(Deck.SIZE))
		var cut: DealResult = DeckOrder.deal(order, state.deck, state.card_marks, deal_stream)
		_check(state, cut)


func test_the_run_deals_its_exchanged_deck_every_round() -> void:
	var stream: RandomStream = RandomStream.new(77)
	for _run: int in 6:
		var state: RunState = _random_deck(stream)
		var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
		loop.start_set()
		var script: RunScript = RunScript.new()
		var rounds: Dictionary[int, bool] = {}
		for _step: int in 600:
			if loop.round_state() != null and not rounds.has(state.round_index):
				rounds[state.round_index] = true
				_check_cards(state, _in_round(loop.round_state()))
			if not script.act(loop):
				break
		assert_int(rounds.size()).is_greater(0)


func test_mass_line_never_makes_an_emptied_rank_wild() -> void:
	var state: RunState = RunState.new(5)
	for slot: int in Deck.SMALL_JOKER_ID:
		if state.deck.rank_of(slot) <= Ranks.TEN:
			DeckExchange.apply(state, slot, Ranks.JACK + slot % 2, slot % 4, CardInstance.NO_ID)
	var counts: PackedByteArray = state.deck.rank_counts()
	var stream: RandomStream = RandomStream.new(9)
	for _draw: int in 200:
		state.wild_ranks.clear()
		while RunWild.has_room(state):
			var rank: int = RunWild.add(state, stream)
			assert_int(counts[rank]).is_greater(0)


## The cards still held and those played so far.
func _in_round(round_state: RoundState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for seat: int in Seats.COUNT:
		cards.append_array(round_state.view_for(seat).own_cards)
	for event: RoundEvent in round_state.events():
		if event.type == RoundEvent.Type.PLAYED:
			cards.append_array(event.cards)
	return cards


func _check(state: RunState, deal: DealResult) -> void:
	var held: Array[CardInstance] = []
	for hand: Hand in deal.hands:
		held.append_array(hand.cards())
	held.append_array(deal.kitty)
	_check_cards(state, held)
	assert_that(deal.deck_counts).is_equal(state.deck.rank_counts())


## The cards are the deck's 54, each slot once, as the deck and its saved marks hold it.
func _check_cards(state: RunState, held: Array[CardInstance]) -> void:
	assert_int(held.size()).is_equal(Deck.SIZE)
	var seen: Dictionary[int, bool] = {}
	for card: CardInstance in held:
		var slot: int = card.id()
		assert_bool(slot >= 0 and slot < Deck.SIZE and not seen.has(slot)).is_true()
		seen[slot] = true
		assert_int(card.base_rank()).is_equal(state.deck.rank_of(slot))
		assert_int(card.suit()).is_equal(state.deck.suit_of(slot))
		var mark: String = state.card_marks.enhancements.get(slot, CardInstance.NO_ID)
		assert_str(card.enhancement_id()).is_equal(mark)

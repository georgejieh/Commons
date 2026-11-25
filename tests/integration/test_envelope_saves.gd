extends GdUnitTestSuite
## Envelopes' plot cards and saves (ADR 0021): a kept plot card enters the plot under a
## new plot ID with its mark, a full plot refuses it, a save taken mid-opening loads back
## into the same envelope and replays exactly, and a marked plot card stays marked through
## a save, a load and a swap into the hand, and scores as marked there.

const RICH: int = 1000


func _at_the_shops(seed_value: int, reforms: Array[String] = []) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.reforms.assign(reforms)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	# Handed over at the Set's end, where the record's checkpoint is, so a replay has them.
	loop.state.coupons = RICH
	loop.record.mark(loop.state)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


func _ids(items: Array[EnvelopeItem]) -> Array[String]:
	var ids: Array[String] = []
	for item: EnvelopeItem in items:
		ids.append("%d:%s:%d:%d" % [item.content, item.item_id, item.rank, item.suit])
	return ids


func _saved(loop: RunLoop) -> Dictionary:
	return JSON.parse_string(JSON.stringify(loop.record.to_dict()))


func _same_state(first: RunLoop, second: RunLoop) -> void:
	assert_str(JSON.stringify(second.state.to_dict())).is_equal(
		JSON.stringify(first.state.to_dict())
	)


## The first seed whose Parcel shows an item of the kind, below 2s if low is set, opened,
## and its index.
func _parcel_with(kind: EnvelopeDef.Content, low: bool = false) -> Array:
	for seed_value: int in 40:
		var loop: RunLoop = _at_the_shops(seed_value)
		loop.player_market_envelope(0)
		var items: Array[EnvelopeItem] = loop.market.envelopes.items()
		for index: int in items.size():
			if items[index].content == kind and (not low or items[index].rank < Ranks.TWO):
				return [loop, index]
	return []


func test_a_kept_plot_card_enters_the_plot_marked_and_a_full_plot_refuses() -> void:
	for kind: EnvelopeDef.Content in [
		EnvelopeDef.Content.STAMPED_CARD, EnvelopeDef.Content.MODEL_CARD
	]:
		var found: Array = _parcel_with(kind)
		assert_array(found).is_not_empty()
		var loop: RunLoop = found[0]
		var index: int = found[1]
		var item: EnvelopeItem = loop.market.envelopes.items()[index]
		var room: int = PlotSwap.capacity(loop.state, RunLoop.DEFAULT_PARAMS)
		var plot: Array[CardInstance] = loop.state.inventory.plot
		while plot.size() < room:
			plot.append(CardInstance.new(loop.state.take_plot_id(), 0, 0, CardInstance.Origin.PLOT))
		assert_int(loop.market.envelopes.check_pick(index)).is_equal(RunShop.Reason.PLOT_FULL)
		assert_int(loop.player_envelope_pick(index)).is_equal(RunLoop.Reason.ILLEGAL)
		plot.pop_back()
		assert_int(loop.player_envelope_pick(index)).is_equal(RunLoop.Reason.OK)
		var card: CardInstance = plot[-1]
		assert_int(plot.size()).is_equal(room)
		assert_int(card.origin()).is_equal(CardInstance.Origin.PLOT)
		assert_bool(card.id() >= CardInstance.FIRST_PLOT_ID).is_true()
		assert_int(card.base_rank()).is_equal(item.rank)
		assert_int(card.suit()).is_equal(item.suit)
		if kind == EnvelopeDef.Content.STAMPED_CARD:
			assert_int(card.owner_stamp()).is_equal(RunLoop.PLAYER)
			assert_str(card.enhancement_id()).is_equal(CardInstance.NO_ID)
		else:
			assert_str(card.enhancement_id()).is_equal(CardInstance.MODEL)
			assert_int(card.owner_stamp()).is_equal(CardInstance.NO_OWNER)
		# No deck card's saved marks change: the mark is the plot card's own.
		assert_bool(loop.state.card_marks.stamps.is_empty()).is_true()


## A save taken with the envelope open loads back into it, showing the same items; the
## pick then replays, and the whole record replays to the same state.
func test_a_save_mid_opening_loads_into_the_same_envelope() -> void:
	for market: bool in [false, true]:
		var loop: RunLoop = _at_the_shops(11)
		loop.player_buy(0)
		if market:
			loop.player_market_envelope(0)
		else:
			loop.player_envelope_buy(0)
		var counter: EnvelopeCounter = loop.open_envelope()
		var saved: Dictionary = _saved(loop)
		assert_bool(RunRecordCheck.is_valid(saved)).is_true()
		var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), SetConfig.new())
		assert_object(resumed).is_not_null()
		assert_object(resumed.open_envelope()).is_not_null()
		assert_str(resumed.open_envelope().opened_id()).is_equal(counter.opened_id())
		assert_array(_ids(resumed.open_envelope().items())).is_equal(_ids(counter.items()))
		_same_state(loop, resumed)
		assert_int(resumed.player_reroll()).is_equal(RunLoop.Reason.NOT_AWAITED)
		var pick: int = 0 if loop.open_envelope().check_pick(0) == RunShop.Reason.OK else -1
		# A card for the deck is kept in place of a deck card (ADR 0042).
		var out: int = Deck.NO_SLOT
		if pick == 0 and loop.open_envelope().items()[0].is_deck_card():
			out = 1
		assert_int(loop.player_envelope_pick(pick, out)).is_equal(RunLoop.Reason.OK)
		assert_int(resumed.player_envelope_pick(pick, out)).is_equal(RunLoop.Reason.OK)
		_same_state(loop, resumed)
		loop.player_reroll()
		var replayed: RunLoop = RunRecord.resume(_saved(loop), RunScript.bots(), SetConfig.new())
		assert_object(replayed).is_not_null()
		_same_state(loop, replayed)
		assert_array(replayed.shop.stock()).is_equal(loop.shop.stock())


## A stamped and a Model plot card from Parcels stay marked through a save and a load, in
## the plot and in the hand they are swapped into, and score as marked there.
func test_marked_plot_cards_survive_save_load_and_a_swap() -> void:
	var stamped: Array = _parcel_with(EnvelopeDef.Content.STAMPED_CARD, true)
	var loop: RunLoop = stamped[0]
	assert_int(loop.player_envelope_pick(stamped[1])).is_equal(RunLoop.Reason.OK)
	# The second mark through the same path a Parcel's Model card takes.
	var item: EnvelopeItem = EnvelopeItem.new(EnvelopeDef.Content.MODEL_CARD, "", Ranks.FIVE, 2)
	EnvelopeContents.take(item, loop.state, RunLoop.DEFAULT_PARAMS, RunLoop.PLAYER, [])
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	var resumed: RunLoop = RunRecord.resume(_saved(loop), RunScript.bots(), SetConfig.new())
	var plot: Array[CardInstance] = resumed.state.inventory.plot
	assert_int(plot.size()).is_equal(2)
	assert_int(plot[0].owner_stamp()).is_equal(RunLoop.PLAYER)
	assert_str(plot[1].enhancement_id()).is_equal(CardInstance.MODEL)
	assert_int(plot[1].base_rank()).is_equal(Ranks.FIVE)
	var script: RunScript = RunScript.new()
	while resumed.awaiting() != RunLoop.Awaiting.PLAYER_SWAP:
		assert_bool(script.act(resumed)).is_true()
	var hand: Array[CardInstance] = resumed.player_cards()
	var given: Array[int] = [hand[0].id()]
	var taken: Array[int] = [plot[0].id()]
	assert_int(resumed.player_swap(given, taken)).is_equal(RunLoop.Reason.OK)
	var arrived: CardInstance = null
	for card: CardInstance in resumed.player_cards():
		if card.id() == taken[0]:
			arrived = card
	assert_object(arrived).is_not_null()
	assert_int(arrived.owner_stamp()).is_equal(RunLoop.PLAYER)
	_check_scoring(arrived, resumed.state.inventory.plot[1])
	_check_class_label(arrived)


func _single(card: CardInstance) -> Pattern:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[card.base_rank()] = 1
	return Classifier.classify(counts, RuleSet.default_rules(), Ranks.identity_map()).pattern


## Red Ink scores the stamped card for its owner; the Model card scores double Grain, and
## double again under Poor Peasants' Association, as a rank from 3 to 7.
func _check_scoring(stamped: CardInstance, model: CardInstance) -> void:
	var plain_stack: ModifierStack = ModifierStack.new()
	var red_ink: ModifierDef = load("res://data/modifiers/red_ink.tres")
	var stack: ModifierStack = ModifierStack.new()
	stack.add(red_ink, RunLoop.PLAYER)
	var cards: Array[CardInstance] = [stamped]
	var plain: float = Scorer.score_play(cards, _single(stamped), 1, 0, false, plain_stack).grain
	var inked: float = Scorer.score_play(cards, _single(stamped), 1, 0, false, stack).grain
	assert_float(inked).is_equal(plain + red_ink.parameters[OwnerStampEffect.GRAIN])
	var bare: CardInstance = CardInstance.new(1, model.base_rank(), model.suit(), model.origin())
	var bare_cards: Array[CardInstance] = [bare]
	var model_cards: Array[CardInstance] = [model]
	var base: float = Scorer.score_play(bare_cards, _single(bare), 1, 0, false, plain_stack).grain
	var doubled: float = (
		Scorer.score_play(model_cards, _single(model), 1, 0, false, plain_stack).grain
	)
	assert_float(doubled).is_equal(base * 2.0)
	var ppa: ModifierDef = load("res://data/modifiers/poor_peasants_association.tres")
	var low_stack: ModifierStack = ModifierStack.new()
	low_stack.add(ppa, RunLoop.PLAYER)
	var low: float = Scorer.score_play(model_cards, _single(model), 1, 0, false, low_stack).grain
	assert_float(low).is_equal(
		Scorer.score_play(bare_cards, _single(bare), 1, 0, false, low_stack).grain * 2.0
	)


## Class Label reads the plot card's stamp in the landlord's hand: its rank rises above 2s
## once every card of it there is stamped, and stays put when the plot card is plain.
func _check_class_label(stamped: CardInstance) -> void:
	for marked: bool in [true, false]:
		var label: ModifierStack = ModifierStack.new()
		label.add(load("res://data/modifiers/class_label.tres"), RunLoop.PLAYER)
		var table: SeatRules = SeatRules.new(label)
		var deck: Array[CardInstance] = []
		for deck_id: int in Deck.SIZE:
			var card: CardInstance = Deck.new().card(deck_id)
			if card.base_rank() == stamped.base_rank():
				CardModifiers.stamp(card, RunLoop.PLAYER)
			deck.append(card)
		var deal: DealResult = Dealer.deal(deck, RandomStream.new(41))
		var round_state: RoundState = RoundState.new(deal, RunLoop.PLAYER, table)
		var incoming: CardInstance = stamped.snapshot()
		if not marked:
			CardModifiers.stamp(incoming, CardInstance.NO_OWNER)
		var given: int = -1
		for card: CardInstance in round_state.view_for(RunLoop.PLAYER).own_cards:
			if card.base_rank() != stamped.base_rank():
				given = card.id()
		var incoming_cards: Array[CardInstance] = [incoming]
		round_state.exchange(RunLoop.PLAYER, [given] as Array[int], incoming_cards)
		round_state.legal_moves()
		var rank_map: PackedByteArray = table.map_for(RunLoop.PLAYER)
		var raised: bool = rank_map[stamped.base_rank()] > rank_map[Ranks.TWO]
		assert_bool(raised).override_failure_message("stamped %s" % marked).is_equal(marked)

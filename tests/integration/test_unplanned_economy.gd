extends GdUnitTestSuite
## Unplanned Economy (ADR 0021): between a Quota's rounds the deck is gathered in the
## order the last round left it, cut once on the deal stream and dealt in order, for every
## seat. The first round of a Quota is shuffled as before, every deal still holds each
## deck card once with its saved marks, and villagers of every tier stay legal.

const SETS: SetParams = preload("res://data/run/default_sets.tres")
const TIERS: Array[BotConfig.Tier] = [
	BotConfig.Tier.EASY, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD, BotConfig.Tier.EXPERT
]
const PROPERTY_SEEDS: int = 12
const STEP_LIMIT: int = 1200
const EXPERT_SAMPLES: int = 4


## A curve no Set can meet, so every Set plays all its rounds.
func _hard_sets() -> SetConfig:
	var params: SetParams = SETS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1e9)
	return SetConfig.new(params)


func _loop(seed_value: int, reformed: bool) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	if reformed:
		state.reforms.append("unplanned_economy")
	return RunLoop.new(state, RunScript.bots(), _hard_sets())


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return ids


## Plays until the loop's round index reaches round_index, or the Set is over.
func _play_to_round(loop: RunLoop, round_index: int, script: RunScript) -> void:
	while loop.state.round_index < round_index and script.act(loop):
		pass


func test_the_first_round_is_shuffled_as_before() -> void:
	for seed_value: int in 8:
		var plain: RunLoop = _loop(seed_value, false)
		var reformed: RunLoop = _loop(seed_value, true)
		plain.start_set()
		reformed.start_set()
		assert_array(reformed.state.deck_order).is_empty()
		assert_array(_ids(reformed.player_cards())).is_equal(_ids(plain.player_cards()))


func test_a_later_round_deals_the_gathered_deck_cut_once() -> void:
	var differed: int = 0
	for seed_value: int in 8:
		var loop: RunLoop = _loop(seed_value, true)
		var plain: RunLoop = _loop(seed_value, false)
		loop.start_set()
		plain.start_set()
		var script: RunScript = RunScript.new()
		_play_to_round(loop, 1, script)
		_play_to_round(plain, 1, RunScript.new())
		if loop.state.round_index != 1:
			continue
		var order: Array[int] = loop.state.deck_order
		assert_bool(DeckOrder.is_valid(order)).is_true()
		assert_int(order.size()).is_equal(Deck.SIZE)
		# The first cards gathered are the first round's plays, in the order played.
		var played: Array[int] = _first_round_plays(loop)
		assert_array(order.slice(0, played.size())).is_equal(played)
		# Seat 0's hand is a run of the gathered deck after one cut.
		var hand: Array[int] = _ids(loop.player_cards())
		hand.sort()
		var found: bool = false
		for at: int in range(1, Deck.SIZE):
			var cut_order: Array[int] = DeckOrder.cut(order, at)
			var dealt: Array[int] = cut_order.slice(0, Dealer.HAND_SIZE)
			# A kept landlord seat has already taken the kitty, the last cards dealt.
			if hand.size() > Dealer.HAND_SIZE:
				dealt.append_array(cut_order.slice(Deck.SIZE - Dealer.KITTY_SIZE))
			dealt.sort()
			found = found or dealt == hand
		assert_bool(found).override_failure_message("seed %d" % seed_value).is_true()
		var shuffled: Array[int] = _ids(plain.player_cards())
		shuffled.sort()
		if shuffled != hand:
			differed += 1
	assert_int(differed).is_greater(0)


func _first_round_plays(loop: RunLoop) -> Array[int]:
	var played: Array[int] = []
	var rounds: int = 0
	for event: RunEvent in loop.events():
		if event.type != RunEvent.Type.ROUND:
			continue
		var inner: RoundEvent = event.round_event
		if inner.type == RoundEvent.Type.ROUND_STARTED:
			rounds += 1
		elif inner.type == RoundEvent.Type.PLAYED and rounds == 1:
			played.append_array(inner.card_ids)
	return played


func test_gathering_keeps_every_deck_card_once_and_plot_cards_out() -> void:
	var whole: Array[int] = DeckOrder.whole([7, 3, CardInstance.FIRST_PLOT_ID + 2, 7, 60, -1])
	assert_int(whole.size()).is_equal(Deck.SIZE)
	assert_array(whole.slice(0, 2)).is_equal([7, 3])
	assert_int(whole[2]).is_equal(0)
	assert_bool(DeckOrder.is_valid(whole)).is_true()
	var order: Array[int] = []
	order.assign(range(Deck.SIZE))
	assert_array(DeckOrder.cut(order, 10).slice(0, 2)).is_equal([10, 11])
	assert_int(DeckOrder.cut(order, 10)[-1]).is_equal(9)


func test_a_gathered_deal_puts_the_saved_marks_back() -> void:
	var marks: CardMarks = CardMarks.new()
	marks.stamps[5] = 0
	marks.enhancements[40] = CardInstance.MODEL
	var order: Array[int] = []
	order.assign(range(Deck.SIZE))
	var deal: DealResult = DeckOrder.deal(order, Deck.new(), marks, RandomStream.new(3))
	var seen: Dictionary[int, CardInstance] = {}
	for hand: Hand in deal.hands:
		assert_int(hand.size()).is_equal(Dealer.HAND_SIZE)
		for card: CardInstance in hand.cards():
			seen[card.id()] = card
	for card: CardInstance in deal.kitty:
		seen[card.id()] = card
	assert_int(seen.size()).is_equal(Deck.SIZE)
	assert_int(seen[5].owner_stamp()).is_equal(0)
	assert_str(seen[40].enhancement_id()).is_equal(CardInstance.MODEL)


## The order is rebuilt by replay, so a save from inside a Set resumes to the same deal.
func test_a_save_inside_a_gathered_set_replays_to_the_same_state() -> void:
	var loop: RunLoop = _loop(31, true)
	loop.start_set()
	var script: RunScript = RunScript.new()
	_play_to_round(loop, 2, script)
	for _turn: int in 2:
		script.act(loop)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), _hard_sets())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.deck_order).is_equal(loop.state.deck_order)
	assert_str(JSON.stringify(resumed.state.to_dict())).is_equal(
		JSON.stringify(loop.state.to_dict())
	)


## The order never outlives its Quota: the next Quota's first round is shuffled again.
func test_the_next_quota_starts_shuffled() -> void:
	var loop: RunLoop = _loop(12, true)
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	assert_array(loop.state.deck_order).is_empty()
	RunScript.next_set(loop)
	assert_array(loop.state.deck_order).is_empty()


func _configs(seed_value: int) -> Array[BotConfig]:
	var configs: Array[BotConfig] = [BotConfig.new(BotConfig.DEFAULT_WEIGHTS, TIERS[1])]
	for seat: int in [1, 2]:
		var tier: BotConfig.Tier = TIERS[(seed_value + seat * 3) % TIERS.size()]
		var weights: BotWeights = BotConfig.DEFAULT_WEIGHTS
		if tier == BotConfig.Tier.EXPERT:
			weights = BotConfig.DEFAULT_WEIGHTS.duplicate()
			weights.expert_samples = EXPERT_SAMPLES
			weights.expert_min_samples = 2
		configs.append(BotConfig.new(weights, tier))
	return configs


## Over many seeds and every tier, with the deck gathered: no villager acts illegally
## (the loop asserts on one), every deck card is in one place, and every Set finishes.
func test_gathered_rounds_stay_legal_and_whole_for_every_tier() -> void:
	var tiers_seen: Dictionary[int, bool] = {}
	var gathered: int = 0
	for seed_value: int in PROPERTY_SEEDS:
		var configs: Array[BotConfig] = _configs(seed_value)
		tiers_seen[configs[1].tier] = true
		tiers_seen[configs[2].tier] = true
		var state: RunState = RunState.new(seed_value + 500)
		state.reforms.append("unplanned_economy")
		var loop: RunLoop = RunLoop.new(state, configs, _hard_sets())
		loop.start_set()
		var script: RunScript = RunScript.new()
		for _step: int in STEP_LIMIT:
			if loop.round_state() != null:
				_check_round(loop)
				if not state.deck_order.is_empty():
					gathered += 1
			if not script.act(loop):
				break
		var over: Array[RunLoop.Awaiting] = [RunLoop.Awaiting.SET_OVER, RunLoop.Awaiting.RUN_OVER]
		assert_bool(over.has(loop.awaiting())).override_failure_message("stuck").is_true()
	assert_int(tiers_seen.size()).is_equal(TIERS.size())
	assert_int(gathered).is_greater(PROPERTY_SEEDS)


func _check_round(loop: RunLoop) -> void:
	var round_state: RoundState = loop.round_state()
	var seen: Dictionary[int, bool] = {}
	for seat: int in Seats.COUNT:
		for card: CardInstance in round_state.view_for(seat).own_cards:
			assert_bool(seen.has(card.id())).override_failure_message("twice").is_false()
			seen[card.id()] = true
	for event: RoundEvent in round_state.events():
		if event.type == RoundEvent.Type.PLAYED:
			for card_id: int in event.card_ids:
				assert_bool(seen.has(card_id)).override_failure_message("replayed").is_false()
				seen[card_id] = true
	assert_int(seen.size()).is_equal(Deck.SIZE)

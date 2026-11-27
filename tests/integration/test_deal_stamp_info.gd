extends GdUnitTestSuite
## P4.9: Planned Allocation biases the deal through the deal hook, an owner stamp scores
## only for its owner in the card-scored hook, and information upgrades add to the
## player's view through explicit flags, so with none it equals a bot's public view.

const ALLOCATION: ModifierDef = preload("res://data/modifiers/planned_allocation.tres")
const RED_INK: ModifierDef = preload("res://data/modifiers/red_ink.tres")
const DEALS: int = 20000
const TOLERANCE: float = 0.02


func _public(view: SeatView) -> Dictionary:
	var history: Array[String] = []
	for entry: PublicPlay in view.public.history:
		history.append("%d:%d:%d" % [entry.seat, entry.pattern.type, entry.pattern.key])
	return {
		"landlord": view.public.landlord,
		"seat_to_act": view.public.seat_to_act,
		"remaining": Array(view.public.remaining),
		"history": history,
		"kitty": Array(view.public.kitty_counts),
		"current": -1 if view.public.current_play == null else view.public.current_play.key,
		"announced": Array(view.public.announced),
	}


func _loop_at_play(cadres: Array[String]) -> RunLoop:
	var state: RunState = RunState.new(4901)
	state.inventory.cadres.assign(cadres)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	var script: RunScript = RunScript.new()
	loop.start_set()
	while loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		script.act(loop)
	return loop


func test_with_no_information_upgrade_the_player_sees_the_public_view() -> void:
	var loop: RunLoop = _loop_at_play([])
	var mine: SeatView = loop.player_view()
	assert_object(mine.info).is_null()
	for seat: int in [1, 2]:
		var theirs: SeatView = loop.round_state().view_for(seat)
		assert_dict(_public(mine)).is_equal(_public(theirs))
		assert_object(theirs.info).is_null()


func test_the_informant_and_peek_add_only_to_the_players_view() -> void:
	var loop: RunLoop = _loop_at_play(["the_informant", "peek"])
	var mine: SeatView = loop.player_view()
	assert_object(mine.info).is_not_null()
	assert_int(mine.info.flags).is_equal(InfoView.OPPONENT_TYPES | InfoView.CLOSEST_HAND)
	assert_bool(mine.info.opponent_types.is_empty()).is_false()
	assert_int(mine.info.closest_seat).is_not_equal(RunLoop.PLAYER)
	var closest: SeatView = loop.round_state().view_for(mine.info.closest_seat)
	assert_array(Array(mine.info.closest_counts)).is_equal(Array(closest.own_counts))
	assert_dict(_public(mine)).is_equal(_public(loop.round_state().view_for(1)))
	assert_object(loop.round_state().view_for(1).info).is_null()


## Each copy of the chosen rank reaches the holder at twice the even chance, ±2 points.
func test_planned_allocation_doubles_the_rank_through_the_deal_hook() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ALLOCATION, 0)
	var stream: RandomStream = RandomStream.new(4902)
	var rank: int = ALLOCATION.parameters[PlannedAllocationEffect.RANK]
	var reached: int = 0
	var copies: int = 0
	for index: int in DEALS:
		var cards: Array[CardInstance] = []
		for deck_id: int in Deck.generate():
			cards.append(CardInstance.from_deck_id(deck_id))
		var deal: DealResult = Dealer.deal(cards, stream)
		stack.run_on_deal(DealContext.new(Seats.NONE, deal, stream))
		reached += deal.hands[0].count_of(rank)
		copies += 4
		assert_int(deal.hands[0].size()).is_equal(17)
	var rate: float = float(reached) / copies
	var target: float = 2.0 * 17.0 / 54.0
	print("planned allocation: %.4f against %.4f" % [rate, target])
	assert_float(rate).is_between(target - TOLERANCE, target + TOLERANCE)


func _score_stamped(seat: int, for_anyone: int) -> float:
	var definition: ModifierDef = RED_INK.duplicate()
	definition.parameters = RED_INK.parameters.duplicate()
	definition.parameters[OwnerStampEffect.FOR_ANYONE] = for_anyone
	var stack: ModifierStack = ModifierStack.new()
	stack.add(definition, 0)
	var card: CardInstance = CardInstance.from_deck_id(20)
	CardModifiers.stamp(card, 0)
	var rules: RuleSet = RuleSet.default_rules()
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[card.base_rank()] = 1
	var pattern: Pattern = Classifier.classify(counts, rules, Ranks.identity_map()).pattern
	return Scorer.score_play([card], pattern, 1, seat, false, stack).total


func test_a_stamped_card_scores_extra_only_for_its_owner() -> void:
	var plain: float = (
		Scorer
		. score_play(
			[CardInstance.from_deck_id(20)],
			(
				Classifier
				. classify(
					_one(CardInstance.from_deck_id(20)),
					RuleSet.default_rules(),
					Ranks.identity_map()
				)
				. pattern
			),
			1,
			1,
			false,
			ModifierStack.new()
		)
		. total
	)
	assert_float(_score_stamped(0, 0)).is_greater(plain)
	assert_float(_score_stamped(1, 0)).is_equal(plain)
	assert_float(_score_stamped(1, 1)).is_greater(plain)


func _one(card: CardInstance) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[card.base_rank()] = 1
	return counts

extends GdUnitTestSuite
## ADR 0021's rank, rule and economy Cadres, one golden scenario each through the hooks
## the engine runs: what each does, its boundary, and who it reaches.

const HOLDER: int = 0
const OTHER: int = 1


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _stack(id: String, memo: CadreMemo = null) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(_def(id), HOLDER, memo)
	return stack


func _map(
	stack: ModifierStack, seat: int, landlord: int = Seats.NONE, stamped: int = 0
) -> PackedByteArray:
	var rank_map: PackedByteArray = Ranks.identity_map()
	var context: RankMapContext = RankMapContext.new(seat, landlord, false, rank_map)
	context.stamped = stamped
	stack.run_build_rank_map(context)
	return rank_map


func _picked(rank: int, years: int = 0) -> CadreMemo:
	var memo: CadreMemo = CadreMemo.new()
	memo.put(CadreMemo.RANK, rank)
	memo.put(CadreMemo.YEARS, years)
	return memo


func test_rehabilitation_moves_the_picked_rank_one_step_a_year() -> void:
	var rank_map: PackedByteArray = _map(_stack("rehabilitation", _picked(Ranks.SEVEN)), HOLDER)
	# One step: 7s sit just above 8s, which drop to where 7s were.
	assert_bool(rank_map[Ranks.SEVEN] > rank_map[Ranks.EIGHT]).is_true()
	assert_bool(rank_map[Ranks.SEVEN] < rank_map[Ranks.NINE]).is_true()
	rank_map = _map(_stack("rehabilitation", _picked(Ranks.SEVEN, 2)), HOLDER)
	assert_bool(rank_map[Ranks.SEVEN] > rank_map[Ranks.TEN]).is_true()
	assert_bool(rank_map[Ranks.SEVEN] < rank_map[Ranks.JACK]).is_true()
	# Hand types still form by printed rank: the map is a permutation, chains untouched.
	var seen: Dictionary[int, bool] = {}
	for value: int in rank_map:
		seen[value] = true
	assert_int(seen.size()).is_equal(Ranks.COUNT)


func test_rehabilitation_stops_below_the_jokers() -> void:
	var rank_map: PackedByteArray = _map(_stack("rehabilitation", _picked(Ranks.KING, 9)), HOLDER)
	assert_bool(rank_map[Ranks.KING] > rank_map[Ranks.TWO]).is_true()
	assert_bool(rank_map[Ranks.KING] < rank_map[Ranks.SMALL_JOKER]).is_true()
	assert_int(rank_map[Ranks.BIG_JOKER]).is_equal(Ranks.BIG_JOKER)
	var effect: RehabilitationEffect = RehabilitationEffect.new()
	effect.parameters = _def("rehabilitation").parameters
	effect.memo = _picked(Ranks.KING, 9)
	assert_int(effect.steps_taken()).is_equal(2)
	effect.memo = _picked(Ranks.TWO, 3)
	assert_int(effect.steps_taken()).is_equal(0)


func test_rehabilitation_is_private_and_falls_back_to_the_datas_rank() -> void:
	var stack: ModifierStack = _stack("rehabilitation", _picked(Ranks.SEVEN))
	assert_array(Array(_map(stack, OTHER))).is_equal(Array(Ranks.identity_map()))
	var fallback: PackedByteArray = _map(_stack("rehabilitation"), HOLDER)
	var rank: int = _def("rehabilitation").parameters["rank"]
	assert_bool(fallback[rank] > fallback[rank + 1]).is_true()


## 3s and 9s are all stamped: both rise above 2s, below the jokers, 3 below 9.
func test_class_label_raises_fully_stamped_ranks_while_the_holder_is_landlord() -> void:
	var stack: ModifierStack = _stack("class_label")
	var stamped: int = (1 << Ranks.THREE) | (1 << Ranks.NINE)
	var rank_map: PackedByteArray = _map(stack, HOLDER, HOLDER, stamped)
	assert_bool(rank_map[Ranks.THREE] > rank_map[Ranks.TWO]).is_true()
	assert_bool(rank_map[Ranks.NINE] > rank_map[Ranks.THREE]).is_true()
	assert_bool(rank_map[Ranks.NINE] < rank_map[Ranks.SMALL_JOKER]).is_true()
	assert_bool(rank_map[Ranks.FOUR] < rank_map[Ranks.TWO]).is_true()
	# Not landlord, or another seat: nothing changes.
	var identity: Array = Array(Ranks.identity_map())
	assert_array(Array(_map(stack, HOLDER, OTHER, stamped))).is_equal(identity)
	assert_array(Array(_map(stack, OTHER, OTHER, stamped))).is_equal(identity)
	# A stamped 2 or joker stays where it is.
	var top: int = (1 << Ranks.TWO) | (1 << Ranks.BIG_JOKER)
	assert_array(Array(_map(stack, HOLDER, HOLDER, top))).is_equal(identity)


## The round tells the rules which ranks the holder holds only stamped cards of: a rank
## with every card stamped rises, a rank with one stamped card among plain ones does not.
func test_the_round_reads_class_labels_ranks_from_the_hand() -> void:
	var table: SeatRules = SeatRules.new(_stack("class_label"))
	var deal: DealResult = Dealer.deal(_deck(), RandomStream.new(41))
	var round_state: RoundState = RoundState.new(deal, HOLDER, table)
	var by_rank: Dictionary[int, Array] = {}
	for card: CardInstance in deal.hands[HOLDER].cards() + deal.kitty:
		if card.base_rank() < Ranks.TWO:
			if not by_rank.has(card.base_rank()):
				by_rank[card.base_rank()] = []
			by_rank[card.base_rank()].append(card)
	var full: int = Ranks.INVALID
	var mixed: int = Ranks.INVALID
	for rank: int in by_rank:
		if full == Ranks.INVALID:
			full = rank
		elif mixed == Ranks.INVALID and by_rank[rank].size() > 1:
			mixed = rank
	for card: CardInstance in by_rank[full]:
		CardModifiers.stamp(card, HOLDER)
	var lone: CardInstance = by_rank[mixed][0]
	CardModifiers.stamp(lone, HOLDER)
	round_state.legal_moves()
	var rank_map: PackedByteArray = table.map_for(HOLDER)
	assert_bool(rank_map[full] > rank_map[Ranks.TWO]).is_true()
	assert_int(rank_map[mixed]).is_less(rank_map[Ranks.TWO])
	assert_array(Array(table.map_for(OTHER))).is_equal(Array(Ranks.identity_map()))


func _deck() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	cards.append_array(Deck.new().cards())
	return cards


func test_shock_brigade_allows_its_holder_four_card_straights_but_not_three() -> void:
	var table: SeatRules = SeatRules.new(_stack("shock_brigade"))
	for seat: int in [OTHER, OTHER + 1]:
		assert_int(table.rules_for(seat).min_straight_length()).is_equal(5)
	var four: PackedByteArray = PackedByteArray()
	four.resize(Ranks.COUNT)
	for rank: int in range(Ranks.FIVE, Ranks.NINE):
		four[rank] = 1
	var three: PackedByteArray = four.duplicate()
	three[Ranks.EIGHT] = 0
	var rules: RuleSet = table.rules_for(HOLDER)
	assert_int(rules.min_straight_length()).is_equal(4)
	var read: Classification = Classifier.classify(four, rules, Ranks.identity_map())
	assert_int(read.pattern.type).is_equal(Pattern.Type.STRAIGHT)
	assert_bool(Classifier.classify(three, rules, Ranks.identity_map()).is_valid()).is_false()
	var moves: Array[Pattern] = MoveGenerator.generate(
		four, _mask(four), null, rules, Ranks.identity_map()
	)
	assert_bool(moves.any(func(move: Pattern) -> bool: return move.card_count == 4)).is_true()
	var other: RuleSet = table.rules_for(OTHER)
	assert_bool(Classifier.classify(four, other, Ranks.identity_map()).is_valid()).is_false()


func _mask(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	return mask


func _pass(stack: ModifierStack, seat: int = HOLDER) -> TurnContext:
	var turn: TurnContext = TurnContext.new(seat, OTHER, null, 10, HOLDER)
	stack.run_turn_taken(turn)
	return turn


func test_ration_coupon_pays_every_fourth_pass_up_to_three_a_quota() -> void:
	var memo: CadreMemo = CadreMemo.new()
	var stack: ModifierStack = _stack("ration_coupon", memo)
	var paid: Array[int] = []
	for _pass_index: int in 16:
		paid.append(_pass(stack).coupons)
	assert_array(paid).is_equal([0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0])
	# A bot's pass and a play earn nothing.
	assert_int(_pass(stack, OTHER).coupons).is_equal(0)
	# The Quota's end starts the count again.
	stack.run_set_end(SetContext.new(0, true))
	assert_int(memo.value(RationCouponEffect.EARNED)).is_equal(0)
	for _pass_index: int in 3:
		_pass(stack)
	assert_int(_pass(stack).coupons).is_equal(1)
	assert_bool(memo.fired).is_true()


func test_the_bookkeeper_pays_one_coupon_per_five_held_up_to_three() -> void:
	var expected: Dictionary[int, int] = {0: 0, 4: 0, 5: 1, 14: 2, 15: 3, 40: 3}
	for held: int in expected:
		var stack: ModifierStack = _stack("the_bookkeeper")
		var ending: SetContext = SetContext.new(0, false)
		ending.coupons = held
		stack.run_set_end(ending)
		assert_int(ending.add_coupons).override_failure_message(str(held)).is_equal(expected[held])


func test_model_commune_raises_the_commons_only_when_the_teammate_went_out_first() -> void:
	var stack: ModifierStack = _stack("model_commune")
	var cases: Array[Array] = [
		# landlord, winner, scale
		[2, 1, 1.5],
		[2, HOLDER, 1.0],
		[2, 2, 1.0],
		[HOLDER, 1, 1.0],
	]
	for case: Array in cases:
		var ending: RoundContext = RoundContext.new(case[0], case[1], RoundEvent.Finish.NORMAL)
		stack.run_round_end(ending)
		assert_float(ending.commons_scale).is_equal(case[2])


func test_planned_allocation_deals_the_picked_rank_and_falls_back_to_its_data() -> void:
	var effect: PlannedAllocationEffect = PlannedAllocationEffect.new()
	effect.parameters = _def("planned_allocation").parameters
	assert_int(effect.picked()).is_equal(Ranks.TWO)
	effect.memo = _picked(Ranks.SEVEN)
	assert_int(effect.picked()).is_equal(Ranks.SEVEN)
	assert_int(effect.state_values()["rank"]).is_equal(Ranks.SEVEN)

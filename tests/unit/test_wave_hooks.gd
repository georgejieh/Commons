extends GdUnitTestSuite
## ADR 0032's Cadres that act outside scoring, one golden scenario each through the hook
## the engine runs: the rule, its boundary, and who it reaches.

const HOLDER: int = 0
const OTHER: int = 1
const THIRD: int = 2
const NEED: int = 12


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _stack(ids: Array[String]) -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in ids:
		stack.add(_def(id), HOLDER)
	return stack


func _settled(
	stack: ModifierStack, landlord: int, declared: int, caught: Array[int]
) -> NeedContext:
	var context: NeedContext = NeedContext.new(HOLDER, landlord, declared, NEED, caught)
	stack.run_need_settled(context)
	return context


func test_open_accounts_lowers_resentment_for_a_claim_no_higher_than_the_need() -> void:
	var stack: ModifierStack = _stack(["open_accounts"])
	var none: Array[int] = []
	assert_int(_settled(stack, OTHER, NEED, none).resentment_fall).is_equal(1)
	assert_int(_settled(stack, OTHER, 3, none).resentment_fall).is_equal(1)
	assert_int(_settled(stack, OTHER, NEED + 1, none).resentment_fall).is_equal(0)
	# A round as landlord declares nothing and counts for nothing.
	var landlord: NeedContext = _settled(stack, HOLDER, NeedContext.NOT_DECLARED, none)
	assert_int(landlord.resentment_fall).is_equal(0)


func test_informers_reward_pays_for_each_villager_caught_and_not_the_player() -> void:
	var stack: ModifierStack = _stack(["informers_reward"])
	var cases: Dictionary[String, Array] = {
		"none": [[], 0],
		"one": [[OTHER], 2],
		"both": [[OTHER, THIRD], 4],
		"player": [[HOLDER], 0],
		"player and one": [[HOLDER, THIRD], 2],
	}
	for name: String in cases:
		var caught: Array[int] = []
		caught.assign(cases[name][0])
		var context: NeedContext = _settled(stack, HOLDER, NeedContext.NOT_DECLARED, caught)
		assert_int(context.coupons).override_failure_message(name).is_equal(cases[name][1])


func _ended(stack: ModifierStack, landlord: int, winner: int, cards: int = 5) -> RoundContext:
	var ending: RoundContext = RoundContext.new(landlord, winner, RoundEvent.Finish.NORMAL)
	ending.landlord_cards = cards
	stack.run_round_end(ending)
	return ending


func test_public_granary_lowers_famine_when_the_peasants_win_with_the_holder() -> void:
	var stack: ModifierStack = _stack(["public_granary"])
	# landlord, winner, fall
	var cases: Array[Array] = [
		[OTHER, THIRD, 1],
		[OTHER, HOLDER, 1],
		[OTHER, OTHER, 0],
		[HOLDER, HOLDER, 0],
		[HOLDER, OTHER, 0],
	]
	for case: Array in cases:
		assert_int(_ended(stack, case[0], case[1]).famine_fall).is_equal(case[2])


## 5% a card: 6 cards left is 1.3 times the Commons; with Model Commune's 1.5, 1.95.
func test_the_gleaners_grow_the_commons_by_the_landlords_cards_left() -> void:
	var stack: ModifierStack = _stack(["the_gleaners"])
	assert_float(_ended(stack, THIRD, OTHER, 6).commons_scale).is_equal_approx(1.3, 0.0001)
	assert_float(_ended(stack, THIRD, HOLDER, 1).commons_scale).is_equal_approx(1.05, 0.0001)
	assert_float(_ended(stack, THIRD, THIRD, 6).commons_scale).is_equal(1.0)
	# The holder as landlord still sees the peasants' Commons grow when they win.
	assert_float(_ended(stack, HOLDER, OTHER, 4).commons_scale).is_equal_approx(1.2, 0.0001)
	var both: ModifierStack = _stack(["model_commune", "the_gleaners"])
	var scale: float = _ended(both, THIRD, OTHER, 6).commons_scale
	assert_float(scale).is_equal_approx(1.95, 0.0001)


func test_grain_speculator_pays_and_resents_each_step_of_overfulfilment() -> void:
	var stack: ModifierStack = _stack(["grain_speculator"])
	for steps: int in [0, 1, 4]:
		var ending: SetContext = SetContext.new(0, steps > 0)
		ending.over_steps = steps
		stack.run_set_end(ending)
		assert_int(ending.add_coupons).is_equal(steps)
		assert_int(ending.add_resentment).is_equal(steps)


func test_back_door_makes_the_first_black_market_reroll_free() -> void:
	var state: RunState = RunState.new(7)
	var definitions: Dictionary[String, ModifierDef] = {}
	for definition: ModifierDef in RunLoop.all_cadres():
		definitions[definition.id] = definition
	assert_int(RunCadres.shop_rules(state, definitions, HOLDER).free_market_rerolls).is_equal(0)
	state.inventory.cadres.assign(["back_door"])
	var rules: ShopContext = RunCadres.shop_rules(state, definitions, HOLDER)
	assert_int(rules.free_market_rerolls).is_equal(1)
	var params: ShopParams = RunLoop.DEFAULT_BLACK_MARKET
	var market: RunShop = RunShop.new(state, params, RunLoop.DEFAULT_MARKET.cadres)
	market.open()
	market.free_rerolls = rules.free_market_rerolls
	state.coupons = 0
	assert_int(market.reroll_price()).is_equal(0)
	assert_int(market.reroll()).is_equal(RunShop.Reason.OK)
	# The second costs what it always did: the base and one step.
	assert_int(market.reroll_price()).is_equal(params.reroll_base + params.reroll_step)
	assert_int(market.reroll()).is_equal(RunShop.Reason.TOO_POOR)
	# A new visit is free again.
	market.open()
	assert_int(market.reroll_price()).is_equal(0)


func test_double_share_plough_lowers_the_shortest_pair_run_for_every_seat() -> void:
	var table: SeatRules = SeatRules.new(_stack(["double_share_plough"]))
	for seat: int in Seats.COUNT:
		assert_int(table.rules_for(seat).min_pair_chain_length()).is_equal(2)
	var plain: SeatRules = SeatRules.new(ModifierStack.new())
	assert_int(plain.rules_for(HOLDER).min_pair_chain_length()).is_equal(3)

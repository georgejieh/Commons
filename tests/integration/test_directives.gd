extends GdUnitTestSuite
## ADR 0021's six Directives: each raises its family of hand types one level at once and
## leaves every other type alone; levels are saved run state that survives a save, a load
## and a replay; the state store offers Directives the same for the same seed, never one
## whose family is all at the top level; buying spends coupons and is refused without
## them.

const POOL: DirectivePool = preload("res://data/run/directive_pool.tres")
const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const SEEDS: int = 60
const RICH: int = 1000
## Each Directive's family and every type's Rate at level 1 and level 2, from
## default_scoring.tres, written out so a change to either shows here.
const FAMILIES: Dictionary[String, Array] = {
	"on_hand_tools": [Pattern.Type.SINGLE, Pattern.Type.PAIR],
	"on_work_teams": [Pattern.Type.TRIO, Pattern.Type.TRIO_SINGLE, Pattern.Type.TRIO_PAIR],
	"on_deep_ploughing": [Pattern.Type.STRAIGHT],
	"on_close_planting": [Pattern.Type.PAIR_CHAIN],
	"on_combined_brigades":
	[Pattern.Type.AIRPLANE, Pattern.Type.AIRPLANE_SINGLES, Pattern.Type.AIRPLANE_PAIRS],
	"on_launching_satellites":
	[
		Pattern.Type.FOUR_TWO_SINGLES,
		Pattern.Type.FOUR_TWO_PAIRS,
		Pattern.Type.BOMB,
		Pattern.Type.ROCKET,
	],
}
const COSTS: Dictionary[String, int] = {
	"on_hand_tools": 3,
	"on_work_teams": 3,
	"on_deep_ploughing": 3,
	"on_close_planting": 3,
	"on_combined_brigades": 4,
	"on_launching_satellites": 5,
}
const RATES: Dictionary[int, Array] = {
	Pattern.Type.SINGLE: [1, 6],
	Pattern.Type.PAIR: [3, 8],
	Pattern.Type.TRIO: [6, 15],
	Pattern.Type.TRIO_SINGLE: [7, 18],
	Pattern.Type.TRIO_PAIR: [10, 22],
	Pattern.Type.STRAIGHT: [7, 18],
	Pattern.Type.PAIR_CHAIN: [7, 17],
	Pattern.Type.AIRPLANE: [11, 24],
	Pattern.Type.AIRPLANE_SINGLES: [12, 26],
	Pattern.Type.AIRPLANE_PAIRS: [15, 32],
	Pattern.Type.FOUR_TWO_SINGLES: [20, 38],
	Pattern.Type.FOUR_TWO_PAIRS: [22, 43],
	Pattern.Type.BOMB: [32, 65],
	Pattern.Type.ROCKET: [50, 96],
}


func _definition(directive_id: String) -> DirectiveDef:
	for directive: DirectiveDef in POOL.directives:
		if directive.id == directive_id:
			return directive
	return null


## A state store that can only offer one Directive.
func _counter(state: RunState, directive_id: String) -> RunShop:
	var only: Array[DirectiveDef] = [_definition(directive_id)]
	var counter: RunShop = RunShop.new(state, STORE, [], 0, only)
	counter.open()
	counter.stock_directives()
	return counter


func _rate(state: RunState, type: int) -> int:
	var level: int = state.hand_levels.level_of(type as Pattern.Type)
	return Scorer.DEFAULT_PARAMS.rate_for(type, level)


## A run that has finished its first Set and opened the shops, with coupons to spend.
func _at_the_shops(seed_value: int, coupons: int = RICH) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = coupons
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


func test_the_pool_is_adr_0021s_six_directives_covering_every_type_once() -> void:
	assert_int(POOL.directives.size()).is_equal(FAMILIES.size())
	var covered: Dictionary[int, bool] = {}
	for directive: DirectiveDef in POOL.directives:
		assert_bool(FAMILIES.has(directive.id)).override_failure_message(directive.id).is_true()
		assert_array(directive.hand_types).is_equal(FAMILIES[directive.id])
		assert_int(directive.cost).is_equal(COSTS[directive.id])
		assert_int(directive.unlock_tier).is_equal(0)
		for type: int in directive.hand_types:
			assert_bool(covered.has(type)).is_false()
			covered[type] = true
	assert_int(covered.size()).is_equal(Pattern.Type.size() - 1)


## One scenario per Directive: its family's Rates go from level 1's to level 2's, and
## every other type keeps level 1's.
func test_each_directive_raises_its_family_and_nothing_else() -> void:
	for directive_id: String in FAMILIES:
		var state: RunState = RunState.new(7)
		state.coupons = RICH
		var counter: RunShop = _counter(state, directive_id)
		assert_array(counter.directive_stock()).is_equal([directive_id])
		for type: int in RATES:
			assert_int(_rate(state, type)).is_equal(RATES[type][0])
		assert_int(counter.buy_directive(0)).is_equal(RunShop.Reason.OK)
		assert_int(state.coupons).is_equal(RICH - COSTS[directive_id])
		for type: int in RATES:
			var raised: bool = FAMILIES[directive_id].has(type)
			var expected: int = RATES[type][1] if raised else RATES[type][0]
			(
				assert_int(_rate(state, type))
				. override_failure_message("%s type %d" % [directive_id, type])
				. is_equal(expected)
			)


## A raised level reaches the table: the next Set's Pairs score at level 2's Rate.
func test_a_raised_level_scores_in_play() -> void:
	var loop: RunLoop = _at_the_shops(31)
	var counter: Array[String] = loop.shop.directive_stock()
	var slot: int = counter.find("on_hand_tools")
	while slot < 0:
		assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
		slot = loop.shop.directive_stock().find("on_hand_tools")
	assert_int(loop.player_directive(slot)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.OK)
	var script: RunScript = RunScript.new()
	var checked: int = 0
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER and script.act(loop):
		pass
	var events: Array[RunEvent] = loop.events()
	for index: int in range(1, events.size()):
		if events[index].type != RunEvent.Type.PLAY_SCORED:
			continue
		var played: RoundEvent = events[index - 1].round_event
		if played == null or played.pattern.type != Pattern.Type.PAIR:
			continue
		assert_float(events[index].rate).is_equal(float(RATES[Pattern.Type.PAIR][1]))
		checked += 1
	assert_int(checked).is_greater(0)


func test_buying_spends_coupons_and_is_refused_without_them() -> void:
	var loop: RunLoop = _at_the_shops(32, 0)
	assert_int(loop.shop.directive_stock().size()).is_equal(STORE.directive_slots)
	var before: Array[int] = loop.state.hand_levels.to_array()
	assert_int(loop.player_directive(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_array(loop.state.hand_levels.to_array()).is_equal(before)
	assert_int(loop.state.coupons).is_equal(0)
	var price: int = loop.shop.directive_price(0)
	loop.state.coupons = price
	assert_int(loop.player_directive(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(0)
	assert_array(loop.state.hand_levels.to_array()).is_not_equal(before)
	# Issued once, then gone from the counter.
	loop.state.coupons = RICH
	assert_int(loop.player_directive(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.state.coupons).is_equal(RICH)
	# The black market issues none.
	assert_int(MARKET.directive_slots).is_equal(0)
	assert_array(loop.market.directive_stock()).is_empty()


func test_the_directive_stock_is_the_same_for_the_same_seed() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: RunLoop = _at_the_shops(seed_value)
		var second: RunLoop = _at_the_shops(seed_value)
		assert_array(first.shop.directive_stock()).is_equal(second.shop.directive_stock())
		assert_int(first.shop.directive_stock().size()).is_equal(STORE.directive_slots)
		assert_int(first.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_int(second.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(first.shop.directive_stock()).is_equal(second.shop.directive_stock())
		seen[",".join(first.shop.directive_stock())] = true
	assert_int(seen.size()).is_greater(10)


## A family all at the top level is never offered; one with a type left below it is.
func test_a_capped_family_is_not_offered() -> void:
	var max_level: int = Scorer.DEFAULT_PARAMS.max_level
	for seed_value: int in SEEDS:
		var state: RunState = RunState.new(seed_value)
		var levels: Array[int] = state.hand_levels.to_array()
		for type: int in FAMILIES["on_hand_tools"]:
			levels[type] = max_level
		levels[Pattern.Type.BOMB] = max_level
		state.hand_levels = HandLevels.from_array(levels, max_level)
		var counter: RunShop = RunShop.new(state, STORE, [], 0, POOL.directives)
		counter.open()
		counter.stock_directives()
		assert_array(counter.directive_stock()).not_contains(["on_hand_tools"])
		for _reroll: int in 3:
			state.coupons = RICH
			counter.reroll()
			assert_array(counter.directive_stock()).not_contains(["on_hand_tools"])
	# Satellites still has types to raise, and raising it leaves Bomb at the top.
	var partial: RunState = RunState.new(1)
	partial.coupons = RICH
	var bomb_top: Array[int] = partial.hand_levels.to_array()
	bomb_top[Pattern.Type.BOMB] = max_level
	partial.hand_levels = HandLevels.from_array(bomb_top, max_level)
	var satellites: RunShop = _counter(partial, "on_launching_satellites")
	assert_array(satellites.directive_stock()).is_equal(["on_launching_satellites"])
	assert_int(satellites.buy_directive(0)).is_equal(RunShop.Reason.OK)
	assert_int(partial.hand_levels.level_of(Pattern.Type.BOMB)).is_equal(max_level)
	assert_int(partial.hand_levels.level_of(Pattern.Type.ROCKET)).is_equal(2)
	# Once every type is at the top, the store has no Directive to offer at all.
	var full: RunState = RunState.new(2)
	var top: Array[int] = []
	for type: int in Pattern.Type.size():
		top.append(max_level)
	full.hand_levels = HandLevels.from_array(top, max_level)
	var empty: RunShop = RunShop.new(full, STORE, [], 0, POOL.directives)
	empty.open()
	empty.stock_directives()
	assert_array(empty.directive_stock()).is_empty()
	assert_bool(empty.reroll_changes()).is_false()


func test_levels_survive_a_save_a_load_and_a_replay() -> void:
	var service: SaveService = SaveService.for_run("user://test_directives/run.json")
	service.delete()
	var loop: RunLoop = _at_the_shops(33)
	assert_int(loop.player_directive(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_directive(1)).is_equal(RunLoop.Reason.OK)
	var record: Dictionary = loop.record.to_dict()
	# The checkpoint was marked at the Set's end, before the test handed out coupons.
	var checkpoint: Dictionary = record["checkpoint"]
	checkpoint["coupons"] = RICH
	assert_int(service.save(record)).is_equal(OK)
	var loaded: SaveLoad = service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var resumed: RunLoop = RunRecord.resume(loaded.data, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	var levels: Array[int] = loop.state.hand_levels.to_array()
	assert_array(resumed.state.hand_levels.to_array()).is_equal(levels)
	assert_int(resumed.state.coupons).is_equal(loop.state.coupons)
	assert_array(resumed.shop.directive_stock()).is_equal(loop.shop.directive_stock())
	# Raised levels are part of the run, so they outlast the shop.
	var text: String = JSON.stringify(loop.state.to_dict())
	var copy: RunState = RunState.from_dict(JSON.parse_string(text))
	assert_array(copy.hand_levels.to_array()).is_equal(levels)
	var raised: int = 0
	for level: int in levels:
		raised += level - 1
	assert_int(raised).is_greater(1)
	service.delete()


func test_every_directive_in_data_is_valid_and_the_validator_catches_bad_ones() -> void:
	var keys: Dictionary[String, bool] = {}
	var file: FileAccess = FileAccess.open("res://data/strings/strings.csv", FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row[0].is_empty():
			keys[row[0]] = true
	for directive: DirectiveDef in POOL.directives:
		assert_array(Array(ModifierValidator.validate_directive(directive, keys))).is_empty()
	var bad: DirectiveDef = _definition("on_hand_tools").duplicate() as DirectiveDef
	bad.hand_types = [Pattern.Type.PASS, Pattern.Type.PAIR, Pattern.Type.PAIR]
	bad.cost = 0
	bad.unlock_tier = -1
	bad.name_key = "directive.nothing.name"
	var problems: String = "\n".join(ModifierValidator.validate_directive(bad, keys))
	for expected: String in ["bad hand type 0", "bad hand type 2", "bad cost", "bad unlock"]:
		assert_str(problems).contains(expected)
	assert_str(problems).contains("missing string key directive.nothing.name")
	bad.hand_types = []
	assert_str("\n".join(ModifierValidator.validate_directive(bad, keys))).contains("no hand")


## Every Cadre carries its unlock tier from ADR 0021's table and ADR 0032's.
func test_cadres_carry_their_unlock_tiers() -> void:
	var tiers: Dictionary[String, int] = {
		"iron_rice_bowl": 0,
		"promotion_of_the_masses": 0,
		"stakhanovite": 0,
		"hidden_reserves": 0,
		"peek": 0,
		"landlords_ledger": 0,
		"cultural_revolution": 1,
		"the_informant": 1,
		"planned_allocation": 2,
		"red_ink": 2,
		"collective_farm": 0,
		"ration_coupon": 0,
		"canteen": 0,
		"red_banner": 0,
		"the_bookkeeper": 0,
		"model_commune": 1,
		"shock_brigade": 1,
		"show_trial": 1,
		"last_sheaf": 1,
		"poor_peasants_association": 2,
		"seed_grain": 2,
		"class_label": 2,
		"rehabilitation": 3,
		"steel_target": 3,
		# ADR 0032's second wave.
		"night_school": 1,
		"iron_and_coal": 1,
		"back_door": 1,
		"advanced_cooperative": 2,
		"double_share_plough": 2,
		"open_accounts": 2,
		"informers_reward": 2,
		"tractor_station": 3,
		"the_gleaners": 3,
		"forged_seal": 3,
		"loudspeaker": 3,
		"public_granary": 4,
		"five_year_plan": 4,
		"rent_book": 4,
		"grain_speculator": 5,
		"prize_exhibit": 5,
	}
	var cadres: Array[ModifierDef] = RunLoop.all_cadres()
	cadres.append(preload("res://data/modifiers/red_ink.tres"))
	for definition: ModifierDef in cadres:
		assert_bool(tiers.has(definition.id)).override_failure_message(definition.id).is_true()
		assert_int(definition.unlock_tier).override_failure_message(definition.id).is_equal(
			tiers[definition.id]
		)

extends GdUnitTestSuite
## Ladders never break a draw rule, over random pools and over the real pool, which holds
## ADR 0023's twenty debuffs at their tiers and levers.

const LADDERS: int = 100000
const SEED: int = 3401
const MAX_POOL: int = 30
const MAX_ROUNDS: int = 6
const PLAN_LADDERS: int = 10000
const POOL: DebuffPool = preload("res://data/run/debuff_pool.tres")
## ADR 0023's table and the six built before it: ID, tier, lever.
const TABLE: Array[Array] = [
	["ration_cut", 1, ModifierDef.Lever.SCORING],
	["paperwork", 1, ModifierDef.Lever.SCORING],
	["morning_meeting", 1, ModifierDef.Lever.SCORING],
	["short_supply", 1, ModifierDef.Lever.ECONOMY],
	["slogan_of_the_week", 1, ModifierDef.Lever.SCORING],
	["levy", 2, ModifierDef.Lever.HAND],
	["work_point_audit", 2, ModifierDef.Lever.METERS],
	["night_shift", 2, ModifierDef.Lever.HAND],
	["grain_tax", 2, ModifierDef.Lever.ECONOMY],
	["straightened_lines", 2, ModifierDef.Lever.SCORING],
	["shared_kitchen", 2, ModifierDef.Lever.HAND],
	["criticism_meeting", 3, ModifierDef.Lever.RANK],
	["confiscation", 3, ModifierDef.Lever.SCORING],
	["glass_walls", 3, ModifierDef.Lever.HAND],
	["redistribution", 3, ModifierDef.Lever.HAND],
	["overtime", 3, ModifierDef.Lever.SCORING],
	["big_character_poster", 4, ModifierDef.Lever.METERS],
	["hungry_winter", 4, ModifierDef.Lever.METERS],
	["plot_seized", 4, ModifierDef.Lever.HAND],
	["inverted_order", 4, ModifierDef.Lever.RANK],
]

var _params: LadderParams = DebuffLadder.DEFAULT_PARAMS


func test_random_ladders_never_break_a_rule() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var stream: RandomStream = RandomStream.new(SEED)
	var violations: int = 0
	var pool: Array[ModifierDef] = _random_pool(rng)
	for index: int in LADDERS:
		if index % 100 == 0:
			pool = _random_pool(rng)
		var set_type: RunState.SetType = rng.randi_range(0, 2) as RunState.SetType
		var rounds: int = rng.randi_range(1, MAX_ROUNDS)
		var ladder: Array[String] = DebuffLadder.draw(pool, set_type, rounds, stream)
		violations += _violations(ladder, pool, set_type, rounds)
	assert_int(violations).is_equal(0)


func test_the_real_pool_holds_every_debuff_at_its_tier_and_lever() -> void:
	var found: Dictionary[String, ModifierDef] = {}
	for definition: ModifierDef in POOL.debuffs:
		assert_int(definition.kind).is_equal(ModifierDef.Kind.DEBUFF)
		found[definition.id] = definition
	assert_int(found.size()).is_equal(TABLE.size())
	for row: Array in TABLE:
		var definition: ModifierDef = found.get(row[0])
		assert_object(definition).override_failure_message(row[0]).is_not_null()
		assert_int(definition.tier).override_failure_message(row[0]).is_equal(row[1])
		assert_int(definition.lever).override_failure_message(row[0]).is_equal(row[2])


## A round can stay clean when the budget and levers leave nothing; the report shows how often.
func test_the_real_pool_never_breaks_a_rule() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var pool: Array[ModifierDef] = POOL.debuffs
	var violations: int = 0
	for index: int in PLAN_LADDERS:
		var set_type: RunState.SetType = (index % 3) as RunState.SetType
		var ladder: Array[String] = DebuffLadder.draw(pool, set_type, 4, stream)
		violations += _violations(ladder, pool, set_type, 4)
	assert_int(violations).is_equal(0)


func test_round_two_draws_only_tiers_one_and_two_weighted_to_two() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var tiers: Dictionary[String, int] = _tiers(POOL.debuffs)
	var tier_two: int = 0
	for _i: int in PLAN_LADDERS:
		var ladder: Array[String] = DebuffLadder.draw(
			POOL.debuffs, RunState.SetType.BOSS, 4, stream
		)
		assert_int(tiers[ladder[1]]).is_between(1, 2)
		if tiers[ladder[1]] == 2:
			tier_two += 1
	# Weights 60 and 30 renormalize to two thirds.
	assert_float(float(tier_two) / PLAN_LADDERS).is_between(0.63, 0.70)


func test_same_stream_state_gives_the_same_ladder() -> void:
	var first: Array[String] = DebuffLadder.draw(
		POOL.debuffs, RunState.SetType.LARGE, 4, RandomStream.new(SEED)
	)
	var second: Array[String] = DebuffLadder.draw(
		POOL.debuffs, RunState.SetType.LARGE, 4, RandomStream.new(SEED)
	)
	assert_array(second).is_equal(first)


func _violations(
	ladder: Array[String], pool: Array[ModifierDef], set_type: RunState.SetType, rounds: int
) -> int:
	if ladder.size() != rounds or ladder[0] != RunState.NO_DEBUFF:
		return 1
	var by_id: Dictionary[String, ModifierDef] = {}
	for definition: ModifierDef in pool:
		by_id[definition.id] = definition
	var seen: Dictionary[String, bool] = {}
	var levers: Dictionary[int, bool] = {}
	var spent: int = 0
	for round_index: int in range(1, rounds):
		var id: String = ladder[round_index]
		if id == RunState.NO_DEBUFF:
			continue
		var definition: ModifierDef = by_id.get(id)
		if definition == null or definition.kind != ModifierDef.Kind.DEBUFF:
			return 1
		if definition.tier > mini(round_index + 1, ModifierDef.MAX_TIER) or definition.tier < 1:
			return 1
		if seen.has(id) or levers.has(definition.lever):
			return 1
		seen[id] = true
		levers[definition.lever] = true
		spent += definition.tier
	return 1 if spent > _params.severity_budgets[set_type] else 0


## Mixed kinds, tiers and levers, so lever and kind filters both get exercised.
func _random_pool(rng: RandomNumberGenerator) -> Array[ModifierDef]:
	var pool: Array[ModifierDef] = []
	for index: int in rng.randi_range(0, MAX_POOL):
		var definition: ModifierDef = _make(
			"debuff_%d" % index,
			rng.randi_range(1, ModifierDef.MAX_TIER),
			rng.randi_range(0, ModifierDef.Lever.size() - 1) as ModifierDef.Lever
		)
		if rng.randi_range(0, 9) == 0:
			definition.kind = ModifierDef.Kind.CADRE
		pool.append(definition)
	return pool


func _tiers(pool: Array[ModifierDef]) -> Dictionary[String, int]:
	var tiers: Dictionary[String, int] = {}
	for definition: ModifierDef in pool:
		tiers[definition.id] = definition.tier
	return tiers


static func _make(id: String, tier: int, lever: ModifierDef.Lever) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.id = id
	definition.kind = ModifierDef.Kind.DEBUFF
	definition.tier = tier
	definition.lever = lever
	return definition

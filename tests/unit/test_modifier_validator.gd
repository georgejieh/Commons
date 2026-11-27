extends GdUnitTestSuite
## Every modifier definition in data is valid, and the validators catch each kind of bad
## definition: Cadres, debuffs, Reforms and Campaigns.

const FIXTURES: String = "res://tests/fixtures/modifiers/"
const DATA: String = "res://data/"
const STRINGS: String = "res://data/strings/strings.csv"


func _string_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if not row[0].is_empty():
			keys[row[0]] = true
	file.close()
	return keys


func _resources_under(folder: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in ResourceLoader.list_directory(folder):
		if file.ends_with("/"):
			paths.append_array(_resources_under(folder + file))
		elif file.ends_with(".tres"):
			paths.append(folder + file)
	return paths


func _load_def(name: String) -> ModifierDef:
	return ResourceLoader.load(DATA + "modifiers/" + name + ".tres")


func test_every_definition_in_data_is_valid() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var checked: int = 0
	var directives: int = 0
	var campaigns: int = 0
	var reforms: int = 0
	for path: String in _resources_under(DATA):
		var resource: Resource = ResourceLoader.load(path)
		var definition: ModifierDef = resource as ModifierDef
		if definition != null:
			checked += 1
			assert_array(Array(ModifierValidator.validate(definition, keys))).is_empty()
		var directive: DirectiveDef = resource as DirectiveDef
		if directive != null:
			directives += 1
			assert_array(Array(ModifierValidator.validate_directive(directive, keys))).is_empty()
		var campaign: CampaignDef = resource as CampaignDef
		if campaign != null:
			campaigns += 1
			assert_array(Array(ModifierValidator.validate_campaign(campaign, keys))).is_empty()
		var reform: ReformDef = resource as ReformDef
		if reform != null:
			reforms += 1
			assert_array(Array(ModifierValidator.validate_reform(reform, keys))).is_empty()
	assert_bool(checked >= 4).is_true()
	# ADR 0021's six Directives and eight Campaigns (P4.11), ADR 0029's Model Worker,
	# Mass Line and Industrialization, ADR 0032's three Campaigns and ADR 0041's three.
	assert_int(directives).is_equal(6)
	assert_int(campaigns).is_equal(15)
	assert_int(reforms).is_equal(8)


## A Reform missing its strings, cost, effect or parameters is caught.
func test_a_broken_reform_is_caught() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var good: ReformDef = load(DATA + "modifiers/reforms/grain_reserve.tres")
	var bad: ReformDef = good.duplicate()
	bad.parameters = {}
	bad.cost = 0
	bad.name_key = "reform.nothing.name"
	var problems: String = "\n".join(ModifierValidator.validate_reform(bad, keys))
	assert_str(problems).contains("missing parameter famine")
	assert_str(problems).contains("bad cost")
	assert_str(problems).contains("missing string key")
	var stray: ReformDef = good.duplicate()
	stray.id = "no_such_reform"
	assert_str("\n".join(ModifierValidator.validate_reform(stray, keys))).contains("no effect")


## ADR 0021's 24 Cadres, ADR 0032's 16 and ADR 0043's Tally Clerk: 20 collective at the
## state store and 21 private at the black market, each with its effect, its parameters,
## its strings, an unlock tier and, where it keeps run state, the line that says where it
## stands.
func test_both_pools_hold_every_cadre_each_complete() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var store: CadrePool = load(DATA + "run/cadre_pool.tres")
	var market: CadrePool = load(DATA + "run/market_pool.tres")
	assert_int(store.cadres.size()).is_equal(20)
	assert_int(market.cadres.size()).is_equal(21)
	var seen: Dictionary[String, bool] = {}
	for definition: ModifierDef in store.cadres + market.cadres:
		assert_bool(seen.has(definition.id)).override_failure_message(definition.id).is_false()
		seen[definition.id] = true
		var problems: PackedStringArray = ModifierValidator.validate(definition, keys)
		assert_array(Array(problems)).override_failure_message(definition.id).is_empty()
		assert_int(definition.kind).is_equal(ModifierDef.Kind.CADRE)
		assert_bool(EffectRegistry.has_effect(definition.id)).is_true()
		var tier: int = definition.unlock_tier
		assert_bool(tier >= 0 and tier <= RunUnlocks.LAST_TIER).is_true()
		assert_int(definition.cost).is_greater(0)
	for definition: ModifierDef in store.cadres:
		assert_int(definition.tag).is_equal(ModifierDef.Tag.COLLECTIVE)
	for definition: ModifierDef in market.cadres:
		assert_int(definition.tag).is_equal(ModifierDef.Tag.PRIVATE)
	# Only the two rank pickers ask for a rank.
	var picking: Array[String] = []
	for definition: ModifierDef in store.cadres + market.cadres:
		if definition.needs_rank:
			picking.append(definition.id)
	picking.sort()
	assert_array(picking).is_equal(["planned_allocation", "rehabilitation"])


func test_the_validator_catches_a_cadre_missing_its_state_line_or_rank() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var no_state: ModifierDef = _load_def("seed_grain").duplicate()
	no_state.state_key = ""
	assert_str(" ".join(ModifierValidator.validate(no_state, keys))).contains("missing state key")
	var stray: ModifierDef = _load_def("canteen").duplicate()
	stray.state_key = "modifier.canteen.text"
	assert_str(" ".join(ModifierValidator.validate(stray, keys))).contains("state key without")
	var no_rank: ModifierDef = _load_def("planned_allocation").duplicate()
	no_rank.parameters = {"percent": 200}
	assert_str(" ".join(ModifierValidator.validate(no_rank, keys))).contains("rank")
	var no_tier: ModifierDef = _load_def("canteen").duplicate()
	no_tier.unlock_tier = -1
	assert_str(" ".join(ModifierValidator.validate(no_tier, keys))).contains("bad unlock tier")


## Each reason a Campaign can be refused has its own line for the tray to show.
func test_every_campaign_refusal_has_a_reason_string() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	for reason: int in CampaignEffect.Reason.values():
		if reason == CampaignEffect.Reason.OK:
			continue
		var key: String = RunTexts.campaign_reason_key(reason)
		assert_bool(keys.has(key)).override_failure_message(key).is_true()


func test_the_campaign_validator_catches_each_kind_of_bad_definition() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var good: CampaignDef = ResourceLoader.load(DATA + "modifiers/campaigns/grain_loan.tres")
	var cases: Dictionary[String, Callable] = {
		"missing string key": func(bad: CampaignDef) -> void: bad.prompt_key = "nope",
		"bad cost": func(bad: CampaignDef) -> void: bad.cost = 0,
		"bad unlock tier": func(bad: CampaignDef) -> void: bad.unlock_tier = -1,
		"bad card count": func(bad: CampaignDef) -> void: bad.min_cards = 3,
		"missing parameter": func(bad: CampaignDef) -> void: bad.parameters = {},
		"no effect script": func(bad: CampaignDef) -> void: bad.id = "nope",
	}
	for problem: String in cases:
		var bad: CampaignDef = good.duplicate()
		cases[problem].call(bad)
		var found: String = "\n".join(ModifierValidator.validate_campaign(bad, keys))
		assert_str(found).contains(problem)


func test_the_validator_catches_each_kind_of_bad_definition() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var cases: Dictionary[String, String] = {
		"bad_hook.tres": "unknown hook",
		"bad_parameter.tres": "missing parameter",
		"bad_effect.tres": "no effect script",
		"bad_string.tres": "missing string key",
		"bad_text.tres": "missing string key",
		"bad_rank.tres": "bad rank",
		"bad_listed_hook.tres": "does not implement",
		"bad_tier.tres": "bad tier",
	}
	for file: String in cases:
		var definition: ModifierDef = ResourceLoader.load(FIXTURES + file)
		var problems: String = "\n".join(ModifierValidator.validate(definition, keys))
		assert_str(problems).contains(cases[file])

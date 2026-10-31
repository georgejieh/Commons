extends GdUnitTestSuite
## Definitions, hook order and derived caches.

const FIXTURES: String = "res://tests/fixtures/modifiers/"
const DATA: String = "res://data/"
const STRINGS: String = "res://data/strings/strings.csv"
const QUERIES: int = 1000


## Writes its label to a shared log from every hook.
class Recorder:
	extends ModifierEffect
	var label: String
	var log: Array[String]

	func _init(name: String, shared: Array[String]) -> void:
		label = name
		log = shared

	func build_ruleset(_context: RulesetContext) -> void:
		log.append(label)

	func build_rank_map(_context: RankMapContext) -> void:
		log.append(label)

	func on_deal(_context: DealContext) -> void:
		log.append(label)

	func round_start(_context: RoundContext) -> void:
		log.append(label)

	func play_scored(_context: PlayContext) -> void:
		log.append(label)

	func card_scored(_context: CardContext) -> void:
		log.append(label)

	func trick_won(_context: TrickContext) -> void:
		log.append(label)

	func round_end(_context: RoundContext) -> void:
		log.append(label)

	func set_end(_context: SetContext) -> void:
		log.append(label)

	func shop_open(_context: ShopContext) -> void:
		log.append(label)

	func meter_change(_context: MeterContext) -> void:
		log.append(label)


## A rules effect of the kind later items will add.
class WildForHolder:
	extends ModifierEffect

	func build_ruleset(context: RulesetContext) -> void:
		if context.seat == holder_seat:
			context.params.wild_ranks.append(Ranks.SEVEN)


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


func _def(kind: ModifierDef.Kind, hooks: Array[String] = []) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = kind
	definition.hooks = hooks
	return definition


func _all_hooks() -> Array[String]:
	var hooks: Array[String] = []
	hooks.assign(Array(Hooks.ALL))
	return hooks


func _load_def(name: String) -> ModifierDef:
	return ResourceLoader.load(DATA + "modifiers/" + name + ".tres")


func test_every_definition_in_data_is_valid() -> void:
	var keys: Dictionary[String, bool] = _string_keys()
	var checked: int = 0
	for path: String in _resources_under(DATA):
		var definition: ModifierDef = ResourceLoader.load(path) as ModifierDef
		if definition != null:
			checked += 1
			assert_array(Array(ModifierValidator.validate(definition, keys))).is_empty()
	assert_bool(checked >= 4).is_true()


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
	}
	for file: String in cases:
		var definition: ModifierDef = ResourceLoader.load(FIXTURES + file)
		var problems: String = "\n".join(ModifierValidator.validate(definition, keys))
		assert_str(problems).contains(cases[file])


func test_the_hook_list_is_complete_and_each_hook_is_a_method() -> void:
	assert_int(Hooks.ALL.size()).is_equal(11)
	var effect: ModifierEffect = ModifierEffect.new()
	for hook: String in Hooks.ALL:
		assert_bool(effect.has_method(hook)).is_true()


func test_architecture_lists_every_hook() -> void:
	var text: String = FileAccess.get_file_as_string("res://docs/ARCHITECTURE.md")
	for hook: String in Hooks.ALL:
		assert_str(text).contains("`%s`" % hook)


func _run_every_hook(stack: ModifierStack) -> void:
	var pass_play: Pattern = Pattern.pass_play()
	var card: CardInstance = CardInstance.from_deck_id(0)
	var finish: RoundEvent.Finish = RoundEvent.Finish.NORMAL
	stack.run_build_ruleset(RulesetContext.new(0, 0, RuleSet.DEFAULT_PARAMS.copy()))
	stack.run_build_rank_map(RankMapContext.new(0, 0, false, Ranks.identity_map()))
	stack.run_on_deal(DealContext.new(0, DealResult.new()))
	stack.run_round_start(RoundContext.new(0, Seats.NONE, finish))
	stack.run_play_scored(PlayContext.new(0, false, pass_play, 0.0, 0.0, 1.0))
	stack.run_card_scored(CardContext.new(0, false, card, 0.0))
	stack.run_trick_won(TrickContext.new(0, 0))
	stack.run_round_end(RoundContext.new(0, 0, finish))
	stack.run_set_end(SetContext.new(0, true))
	stack.run_shop_open(ShopContext.new(0))
	stack.run_meter_change(MeterContext.new("famine", 1))


func test_every_hook_runs_cadres_then_debuffs_then_the_boss() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var log: Array[String] = []
	var rows: Array[Array] = [
		["boss", ModifierDef.Kind.BOSS_TWIST],
		["debuff one", ModifierDef.Kind.DEBUFF],
		["cadre left", ModifierDef.Kind.CADRE],
		["debuff two", ModifierDef.Kind.DEBUFF],
		["cadre right", ModifierDef.Kind.CADRE],
	]
	for row: Array in rows:
		stack.add_entry(ActiveModifier.new(_def(row[1], _all_hooks()), Recorder.new(row[0], log)))
	_run_every_hook(stack)
	var expected: Array[String] = []
	for _hook: String in Hooks.ALL:
		expected.append_array(["cadre left", "cadre right", "debuff one", "debuff two", "boss"])
	assert_array(log).is_equal(expected)


func test_disabled_modifiers_do_not_run() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var log: Array[String] = []
	var entry: ActiveModifier = ActiveModifier.new(
		_def(ModifierDef.Kind.CADRE, _all_hooks()), Recorder.new("x", log)
	)
	stack.add_entry(entry)
	stack.set_enabled(entry, false)
	_run_every_hook(stack)
	assert_int(log.size()).is_equal(0)
	stack.set_enabled(entry, true)
	_run_every_hook(stack)
	assert_int(log.size()).is_equal(Hooks.ALL.size())


func test_a_modifier_runs_only_on_the_hooks_it_lists() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var log: Array[String] = []
	var listed: Array[String] = [Hooks.TRICK_WON]
	stack.add_entry(
		ActiveModifier.new(_def(ModifierDef.Kind.CADRE, listed), Recorder.new("x", log))
	)
	_run_every_hook(stack)
	assert_int(log.size()).is_equal(1)


func test_a_rebuild_visits_each_modifier_once_per_seat() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var log: Array[String] = []
	var listed: Array[String] = [Hooks.BUILD_RANK_MAP]
	for index: int in 4:
		var effect: Recorder = Recorder.new(str(index), log)
		stack.add_entry(ActiveModifier.new(_def(ModifierDef.Kind.CADRE, listed), effect))
	var table: SeatRules = SeatRules.new(stack)
	log.clear()
	table.start_round(0)
	assert_int(log.size()).is_equal(4 * Seats.COUNT)


func test_ruleset_hooks_can_not_touch_other_seats_or_the_defaults() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var effect: WildForHolder = WildForHolder.new()
	effect.holder_seat = 0
	var listed: Array[String] = [Hooks.BUILD_RULESET]
	stack.add_entry(ActiveModifier.new(_def(ModifierDef.Kind.CADRE, listed), effect))
	var table: SeatRules = SeatRules.new(stack)
	table.start_round(1)
	assert_bool(table.rules_for(0).is_wild(Ranks.SEVEN)).is_true()
	assert_bool(table.rules_for(1).is_wild(Ranks.SEVEN)).is_false()
	assert_bool(table.rules_for(2).is_wild(Ranks.SEVEN)).is_false()
	assert_int(RuleSet.default_rules().wild_ranks().size()).is_equal(0)


func test_effects_can_not_write_to_their_definition() -> void:
	var definition: ModifierDef = _load_def("promotion_of_the_masses")
	var effect: ModifierEffect = EffectRegistry.create(definition, 0)
	effect.parameters["rank"] = Ranks.TEN
	assert_int(definition.parameters["rank"]).is_equal(Ranks.THREE)


func test_queries_never_rebuild() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(_load_def("promotion_of_the_masses"), 0)
	var table: SeatRules = SeatRules.new(stack)
	table.start_round(0)
	var before: int = table.rebuilds
	var counts: PackedByteArray = RankText.counts("3334")
	var deal: DealResult = RoundScript.stacked_deal(["3456", "789", "TJQ"], "")
	var round_state: RoundState = RoundState.new(deal, 0, table)
	before = table.rebuilds
	for index: int in QUERIES:
		var seat: int = index % Seats.COUNT
		Classifier.classify(counts, table.rules_for(seat), table.map_for(seat))
		round_state.legal_moves()
	assert_int(table.rebuilds).is_equal(before)


func test_each_change_marks_the_cache_for_one_rebuild() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var table: SeatRules = SeatRules.new(stack)
	var before: int = table.rebuilds
	var entry: ActiveModifier = stack.add(_load_def("promotion_of_the_masses"), 0)
	table.refresh()
	assert_int(table.rebuilds).is_equal(before + 1)
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.TWO)
	table.refresh()
	assert_int(table.rebuilds).is_equal(before + 1)
	stack.set_enabled(entry, false)
	table.refresh()
	assert_int(table.rebuilds).is_equal(before + 2)
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.THREE)
	stack.set_enabled(entry, true)
	table.refresh()
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.TWO)
	stack.remove(entry)
	table.refresh()
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.THREE)
	var after_remove: int = table.rebuilds
	table.start_round(1)
	assert_int(table.rebuilds).is_equal(after_remove + 1)

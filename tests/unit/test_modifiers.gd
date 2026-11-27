extends GdUnitTestSuite
## Hook order and derived caches.

const DATA: String = "res://data/"
const QUERIES: int = 1000


## Writes its label to a shared list of calls from every hook. Held by seat 0, the seat every
## hook below is run for.
class Recorder:
	extends ModifierEffect
	var label: String
	var calls: Array[String]

	func _init(name: String, shared: Array[String]) -> void:
		label = name
		calls = shared
		holder_seat = 0

	func build_ruleset(_context: RulesetContext) -> void:
		calls.append(label)

	func build_rank_map(_context: RankMapContext) -> void:
		calls.append(label)

	func on_deal(_context: DealContext) -> void:
		calls.append(label)

	func round_start(_context: RoundContext) -> void:
		calls.append(label)

	func play_scored(_context: PlayContext) -> void:
		calls.append(label)

	func card_scored(_context: CardContext) -> void:
		calls.append(label)

	func round_end(_context: RoundContext) -> void:
		calls.append(label)

	func set_end(_context: SetContext) -> void:
		calls.append(label)

	func shop_open(_context: ShopContext) -> void:
		calls.append(label)

	func meter_change(_context: MeterContext) -> void:
		calls.append(label)

	func audit(_context: AuditContext) -> void:
		calls.append(label)

	func turn_taken(_context: TurnContext) -> void:
		calls.append(label)

	func need_settled(_context: NeedContext) -> void:
		calls.append(label)


## A rules effect of the kind later items will add.
class WildForHolder:
	extends ModifierEffect

	func build_ruleset(context: RulesetContext) -> void:
		if context.seat == holder_seat:
			context.params.wild_ranks.append(Ranks.SEVEN)


func _def(kind: ModifierDef.Kind, hooks: Array[String] = []) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = kind
	definition.hooks = hooks
	return definition


func _all_hooks() -> Array[String]:
	var hooks: Array[String] = []
	hooks.assign(Array(Hooks.ALL))
	return hooks


func _load_def(modifier_id: String) -> ModifierDef:
	return ResourceLoader.load(DATA + "modifiers/" + modifier_id + ".tres")


func test_the_hook_list_is_complete_and_each_hook_is_a_method() -> void:
	assert_int(Hooks.ALL.size()).is_equal(13)
	var effect: ModifierEffect = ModifierEffect.new()
	for hook: String in Hooks.ALL:
		assert_bool(effect.has_method(hook)).is_true()


func test_architecture_lists_every_hook() -> void:
	var text: String = FileAccess.get_file_as_string("res://docs/ARCHITECTURE.md")
	for hook: String in Hooks.ALL:
		assert_str(text).contains("`%s`" % hook)


func _run_every_hook(stack: ModifierStack) -> void:
	var pass_play: Pattern = Pattern.pass_play()
	var card: CardInstance = Deck.new().card(0)
	var finish: RoundEvent.Finish = RoundEvent.Finish.NORMAL
	stack.run_build_ruleset(RulesetContext.new(0, 0, RuleSet.DEFAULT_PARAMS.copy()))
	stack.run_build_rank_map(RankMapContext.new(0, 0, false, Ranks.identity_map()))
	stack.run_on_deal(DealContext.new(0, DealResult.new(), RandomStream.new(1)))
	stack.run_round_start(RoundContext.new(0, Seats.NONE, finish))
	stack.run_play_scored(PlayContext.new(0, false, pass_play, 0.0, 0.0, 1.0))
	stack.run_card_scored(CardContext.new(0, false, card, 0.0))
	stack.run_round_end(RoundContext.new(0, 0, finish))
	stack.run_set_end(SetContext.new(0, true))
	stack.run_shop_open(ShopContext.new(0))
	stack.run_meter_change(MeterContext.new("famine", 1))
	stack.run_audit(AuditContext.new(0))
	stack.run_turn_taken(TurnContext.new(0, 0, null, 0, 0))
	var no_one: Array[int] = []
	stack.run_need_settled(NeedContext.new(0, 0, NeedContext.NOT_DECLARED, 1, no_one))


func test_every_hook_runs_cadres_then_debuffs_then_the_boss() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var calls: Array[String] = []
	var rows: Array[Array] = [
		["boss", ModifierDef.Kind.BOSS_TWIST],
		["debuff one", ModifierDef.Kind.DEBUFF],
		["cadre left", ModifierDef.Kind.CADRE],
		["debuff two", ModifierDef.Kind.DEBUFF],
		["cadre right", ModifierDef.Kind.CADRE],
	]
	for row: Array in rows:
		stack.add_entry(ActiveModifier.new(_def(row[1], _all_hooks()), Recorder.new(row[0], calls)))
	_run_every_hook(stack)
	var expected: Array[String] = []
	for _hook: String in Hooks.ALL:
		expected.append_array(["cadre left", "cadre right", "debuff one", "debuff two", "boss"])
	assert_array(calls).is_equal(expected)


func test_disabled_modifiers_do_not_run() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var calls: Array[String] = []
	var entry: ActiveModifier = ActiveModifier.new(
		_def(ModifierDef.Kind.CADRE, _all_hooks()), Recorder.new("x", calls)
	)
	stack.add_entry(entry)
	stack.set_enabled(entry, false)
	_run_every_hook(stack)
	assert_int(calls.size()).is_equal(0)
	stack.set_enabled(entry, true)
	_run_every_hook(stack)
	assert_int(calls.size()).is_equal(Hooks.ALL.size())


func test_a_modifier_runs_only_on_the_hooks_it_lists() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var calls: Array[String] = []
	var listed: Array[String] = [Hooks.SET_END]
	stack.add_entry(
		ActiveModifier.new(_def(ModifierDef.Kind.CADRE, listed), Recorder.new("x", calls))
	)
	_run_every_hook(stack)
	assert_int(calls.size()).is_equal(1)


## A debuff's hook builds every seat and leaves the seat to the effect; a Cadre's builds
## its holder's seat alone (ADR 0039).
func test_a_rebuild_visits_each_modifier_once_per_seat_it_reaches() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var calls: Array[String] = []
	var listed: Array[String] = [Hooks.BUILD_RANK_MAP]
	for index: int in 4:
		var effect: Recorder = Recorder.new(str(index), calls)
		stack.add_entry(ActiveModifier.new(_def(ModifierDef.Kind.DEBUFF, listed), effect))
	var cadre: Recorder = Recorder.new("cadre", calls)
	cadre.holder_seat = 1
	stack.add_entry(ActiveModifier.new(_def(ModifierDef.Kind.CADRE, listed), cadre))
	var table: SeatRules = SeatRules.new(stack)
	calls.clear()
	table.start_round(0)
	assert_int(calls.size()).is_equal((4 * Seats.COUNT + 1) * SeatRules.MAPS_PER_SEAT)
	assert_int(calls.count("cadre")).is_equal(SeatRules.MAPS_PER_SEAT)


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
	var was: int = table.rebuilds
	var counts: PackedByteArray = RankText.counts("3334")
	var deal: DealResult = RoundScript.stacked_deal(["3456", "789", "TJQ"], "")
	var round_state: RoundState = RoundState.new(deal, 0, table)
	was = table.rebuilds
	for index: int in QUERIES:
		var seat: int = index % Seats.COUNT
		Classifier.classify(counts, table.rules_for(seat), table.map_for(seat))
		round_state.legal_moves()
	assert_int(table.rebuilds).is_equal(was)


func test_each_change_marks_the_cache_for_one_rebuild() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var table: SeatRules = SeatRules.new(stack)
	var was: int = table.rebuilds
	var entry: ActiveModifier = stack.add(_load_def("promotion_of_the_masses"), 0)
	table.refresh()
	assert_int(table.rebuilds).is_equal(was + 1)
	assert_int(table.map_for(0)[Ranks.THREE]).is_equal(Ranks.TWO)
	table.refresh()
	assert_int(table.rebuilds).is_equal(was + 1)
	stack.set_enabled(entry, false)
	table.refresh()
	assert_int(table.rebuilds).is_equal(was + 2)
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

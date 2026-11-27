extends GdUnitTestSuite
## P4.3: the audit chance is base + informer + the audit hook; a checked lie is caught
## and replaced by the true need, so the split is made on honest needs.

const PARAMS: AuditParams = preload("res://data/run/audit.tres")
const TRUE_NEED: int = 10
const SPLITS: int = 10000


## Raises every audit to certain, as the Work-Point Audit debuff will.
class AuditAll:
	extends ModifierEffect

	func audit(context: AuditContext) -> void:
		context.chance = 1.0


func _audit_stack() -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = ModifierDef.Kind.DEBUFF
	definition.hooks.assign([Hooks.AUDIT])
	stack.add_entry(ActiveModifier.new(definition, AuditAll.new()))
	return stack


func test_the_chance_is_base_without_an_informer() -> void:
	var state: RunState = RunState.new(1)
	assert_float(NeedAudit.chance(state, PARAMS, ModifierStack.new())).is_equal(PARAMS.base_chance)


func test_an_informer_at_the_table_or_on_the_roster_adds_to_the_chance() -> void:
	var expected: float = PARAMS.base_chance + PARAMS.informer_chance
	var seated: RunState = RunState.new(1)
	seated.table.assign(["player", PARAMS.informer_families[0], "li"])
	assert_float(NeedAudit.chance(seated, PARAMS, ModifierStack.new())).is_equal_approx(
		expected, 1e-6
	)
	var village: RunState = RunState.new(1)
	village.roster.append(RosterEntry.new(PARAMS.informer_families[0]))
	assert_bool(NeedAudit.informer_present(village, PARAMS)).is_true()
	village.roster[0].status = RosterEntry.Status.DEAD
	assert_bool(NeedAudit.informer_present(village, PARAMS)).is_false()


func test_the_audit_hook_can_make_every_check_certain() -> void:
	assert_float(NeedAudit.chance(RunState.new(1), PARAMS, _audit_stack())).is_equal(1.0)


func test_a_checked_lie_is_caught_and_an_honest_need_is_not() -> void:
	var needs: PackedInt64Array = PackedInt64Array([TRUE_NEED + 7, TRUE_NEED])
	var events: Array[RunEvent] = []
	var seats: Array[int] = [0, 2]
	var caught: Array[int] = NeedAudit.run(
		seats, needs, TRUE_NEED, 1.0, RandomStream.new(5), events
	)
	assert_array(caught).contains_exactly([0])
	assert_int(needs[0]).is_equal(TRUE_NEED)
	assert_int(events.size()).is_equal(2)
	assert_int(events[0].value).is_equal(1)
	assert_int(events[1].value).is_equal(0)


func test_no_chance_checks_nothing() -> void:
	var needs: PackedInt64Array = PackedInt64Array([TRUE_NEED + 7, TRUE_NEED + 7])
	var events: Array[RunEvent] = []
	var seats: Array[int] = [1, 2]
	(
		assert_array(NeedAudit.run(seats, needs, TRUE_NEED, 0.0, RandomStream.new(5), events))
		. is_empty()
	)
	assert_int(needs[0]).is_equal(TRUE_NEED + 7)
	assert_array(events).is_empty()


func test_the_stream_moves_the_same_whether_or_not_anyone_lied() -> void:
	var honest: RandomStream = RandomStream.new(9)
	var lying: RandomStream = RandomStream.new(9)
	var events: Array[RunEvent] = []
	var seats: Array[int] = [1, 2]
	NeedAudit.run(seats, PackedInt64Array([TRUE_NEED, TRUE_NEED]), TRUE_NEED, 0.5, honest, events)
	NeedAudit.run(seats, PackedInt64Array([50, 50]), TRUE_NEED, 0.5, lying, events)
	assert_str(honest.save_state()).is_equal(lying.save_state())


func test_the_split_after_a_caught_lie_uses_honest_needs() -> void:
	var state: RunState = RunState.new(7)
	state.landlord_seat = 1
	state.commons_pool = 1000
	var events: Array[RunEvent] = []
	var caught: Array[int] = []
	var params: RunParams = RunLoop.DEFAULT_PARAMS
	RoundBanking.split(state, 0, 90, RunScript.bots(), params, events, 1.0, caught)
	assert_array(caught).contains([0])
	var honest: PackedInt64Array = Banking.split(
		1000, PackedInt64Array([params.base_need, params.base_need])
	)
	assert_float(state.set_progress).is_equal(float(honest[0]))


## Over 10,000 splits, every bot lies and the player declares above true need. Checked
## declarations come to the configured chance within one point, the shares paid always
## equal a split of the needs left standing, and a lone caught liar's share falls.
func _simulate(chance: float) -> float:
	var state: RunState = RunState.new(77)
	state.landlord_seat = 1
	var configs: Array[BotConfig] = RunScript.bots()
	for config: BotConfig in configs:
		config.honesty = 0.0
	var params: RunParams = RunLoop.DEFAULT_PARAMS
	var declared: int = 0
	var checked: int = 0
	for index: int in SPLITS:
		state.commons_pool = 10000
		var events: Array[RunEvent] = []
		var caught: Array[int] = []
		RoundBanking.split(state, 0, TRUE_NEED + 20, configs, params, events, chance, caught)
		var standing: PackedInt64Array = PackedInt64Array()
		var lied: PackedInt64Array = PackedInt64Array()
		var paid: PackedInt64Array = PackedInt64Array()
		for event: RunEvent in events:
			match event.type:
				RunEvent.Type.NEED_DECLARED:
					declared += 1
					lied.append(event.value)
					standing.append(event.value)
				RunEvent.Type.AUDITED:
					checked += 1
				RunEvent.Type.SHARE_PAID:
					paid.append(event.value)
		var seats: Array[int] = [0, 2]
		for slot: int in seats.size():
			if caught.has(seats[slot]):
				standing[slot] = params.base_need
		assert_array(Array(paid)).is_equal(Array(Banking.split(10000, standing)))
		if caught.size() == 1:
			var slot: int = seats.find(caught[0])
			assert_int(paid[slot]).is_less(Banking.split(10000, lied)[slot])
	return float(checked) / declared


func test_audit_rates_match_the_configuration_over_10000_splits() -> void:
	for chance: float in [PARAMS.base_chance, PARAMS.base_chance + PARAMS.informer_chance]:
		var rate: float = _simulate(chance)
		print("configured %.3f, audited %.4f" % [chance, rate])
		assert_float(rate).is_between(chance - 0.01, chance + 0.01)

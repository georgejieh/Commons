extends GdUnitTestSuite
## P4.3: the audit chance is base + informer + the audit hook; a checked lie is caught
## and replaced by the true need, so the split is made on honest needs.

const PARAMS: AuditParams = preload("res://data/run/audit.tres")
const TRUE_NEED: int = 10


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

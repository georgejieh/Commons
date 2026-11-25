extends GdUnitTestSuite
## P4.3: each declaring seat rolls the audit die once, and a face at or below the audit
## faces checks its claim. The faces are base + informer + the audit hook, capped below
## certain; a checked lie is caught and replaced by the true need, so the split is made
## on honest needs.

const PARAMS: AuditParams = preload("res://data/run/audit.tres")
const TRUE_NEED: int = 10
const SPLITS: int = 10000
const SEEDS: int = 4000


## Adds every face it can to the audit, as the Work-Point Audit debuff might.
class AuditAll:
	extends ModifierEffect

	func audit(context: AuditContext) -> void:
		context.faces += 10


func _audit_stack() -> ModifierStack:
	var stack: ModifierStack = ModifierStack.new()
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = ModifierDef.Kind.DEBUFF
	definition.hooks.assign([Hooks.AUDIT])
	stack.add_entry(ActiveModifier.new(definition, AuditAll.new()))
	return stack


func test_the_faces_are_base_without_an_informer() -> void:
	var state: RunState = RunState.new(1)
	assert_int(NeedAudit.faces(state, PARAMS, ModifierStack.new())).is_equal(PARAMS.base_faces)
	var chance: float = NeedAudit.chance(state, PARAMS, ModifierStack.new())
	assert_float(chance).is_equal_approx(1.0 / 6.0, 1e-6)
	assert_int(roundi(chance * 100.0)).is_equal(17)


func test_an_informer_at_the_table_or_on_the_roster_adds_a_face() -> void:
	var expected: int = PARAMS.base_faces + PARAMS.informer_faces
	var seated: RunState = RunState.new(1)
	seated.table.assign(["player", PARAMS.informer_families[0], "li"])
	assert_int(NeedAudit.faces(seated, PARAMS, ModifierStack.new())).is_equal(expected)
	assert_float(NeedAudit.chance(seated, PARAMS, ModifierStack.new())).is_equal_approx(
		2.0 / 6.0, 1e-6
	)
	var village: RunState = RunState.new(1)
	village.roster.append(RosterEntry.new(PARAMS.informer_families[0]))
	assert_bool(NeedAudit.informer_present(village, PARAMS)).is_true()
	village.roster[0].status = RosterEntry.Status.DEAD
	assert_bool(NeedAudit.informer_present(village, PARAMS)).is_false()


func test_the_hook_adds_faces_but_never_past_max_faces() -> void:
	var faces: int = NeedAudit.faces(RunState.new(1), PARAMS, _audit_stack())
	assert_int(faces).is_equal(PARAMS.max_faces)
	assert_int(faces).is_less(PARAMS.die_sides)
	assert_float(NeedAudit.chance(RunState.new(1), PARAMS, _audit_stack())).is_less(1.0)


func test_every_seat_rolls_and_every_roll_comes_before_any_audit() -> void:
	var needs: PackedInt64Array = PackedInt64Array([TRUE_NEED + 7, TRUE_NEED])
	var events: Array[RunEvent] = []
	var seats: Array[int] = [0, 2]
	var caught: Array[int] = NeedAudit.run(
		seats, needs, TRUE_NEED, PARAMS.die_sides, PARAMS.die_sides, RandomStream.new(5), events
	)
	# Every face is an audit face here, so both claims are checked.
	assert_array(caught).contains_exactly([0])
	assert_int(needs[0]).is_equal(TRUE_NEED)
	assert_int(events.size()).is_equal(4)
	assert_int(events[0].type).is_equal(RunEvent.Type.AUDIT_ROLLED)
	assert_int(events[1].type).is_equal(RunEvent.Type.AUDIT_ROLLED)
	assert_int(events[0].seat).is_equal(0)
	assert_int(events[1].seat).is_equal(2)
	assert_float(events[0].amount).is_equal(float(PARAMS.die_sides))
	assert_int(events[2].type).is_equal(RunEvent.Type.AUDITED)
	assert_int(events[2].value).is_equal(1)
	assert_int(events[3].value).is_equal(0)


func test_no_faces_checks_nothing_but_still_rolls() -> void:
	var needs: PackedInt64Array = PackedInt64Array([TRUE_NEED + 7, TRUE_NEED + 7])
	var events: Array[RunEvent] = []
	var seats: Array[int] = [1, 2]
	var stream: RandomStream = RandomStream.new(5)
	(
		assert_array(NeedAudit.run(seats, needs, TRUE_NEED, 0, PARAMS.die_sides, stream, events))
		. is_empty()
	)
	assert_int(needs[0]).is_equal(TRUE_NEED + 7)
	assert_int(events.size()).is_equal(2)
	for event: RunEvent in events:
		assert_int(event.type).is_equal(RunEvent.Type.AUDIT_ROLLED)


func test_the_roll_is_the_same_for_the_same_seed() -> void:
	for seed_value: int in 50:
		var first: Array[RunEvent] = _roll(seed_value, 1)
		var second: Array[RunEvent] = _roll(seed_value, 1)
		assert_int(first.size()).is_equal(second.size())
		for index: int in first.size():
			assert_str(first[index].describe()).is_equal(second[index].describe())


## The face each roll shows is what decided it: an audit follows exactly the seats whose
## face was at or below the audit faces.
func test_the_face_in_the_event_decides_the_audit() -> void:
	for seed_value: int in 300:
		var faces: int = 1 + seed_value % 3
		var expected: Array[int] = []
		var audited: Array[int] = []
		for event: RunEvent in _roll(seed_value, faces):
			if event.type == RunEvent.Type.AUDIT_ROLLED:
				assert_int(event.value).is_between(1, PARAMS.die_sides)
				assert_int(roundi(event.amount)).is_equal(faces)
				if event.value <= faces:
					expected.append(event.seat)
			elif event.type == RunEvent.Type.AUDITED:
				audited.append(event.seat)
		assert_array(audited).is_equal(expected)


func test_the_stream_moves_the_same_whether_or_not_anyone_lied() -> void:
	var honest: RandomStream = RandomStream.new(9)
	var lying: RandomStream = RandomStream.new(9)
	var events: Array[RunEvent] = []
	var seats: Array[int] = [1, 2]
	var fair: PackedInt64Array = PackedInt64Array([TRUE_NEED, TRUE_NEED])
	NeedAudit.run(seats, fair, TRUE_NEED, 3, PARAMS.die_sides, honest, events)
	NeedAudit.run(seats, PackedInt64Array([50, 50]), TRUE_NEED, 3, PARAMS.die_sides, lying, events)
	assert_str(honest.save_state()).is_equal(lying.save_state())


## Over many seeds the share of claims audited comes to the faces over the sides: one
## face in six alone, two with the informer.
func test_the_audit_share_comes_to_the_faces_over_the_sides() -> void:
	var informer: int = PARAMS.base_faces + PARAMS.informer_faces
	for faces: int in [PARAMS.base_faces, informer]:
		var rolled: int = 0
		var audited: int = 0
		for seed_value: int in SEEDS:
			for event: RunEvent in _roll(seed_value, faces):
				if event.type == RunEvent.Type.AUDIT_ROLLED:
					rolled += 1
				elif event.type == RunEvent.Type.AUDITED:
					audited += 1
		var share: float = float(audited) / rolled
		var expected: float = float(faces) / PARAMS.die_sides
		print("faces %d, audited %.4f of %d" % [faces, share, rolled])
		assert_float(share).is_between(expected - 0.015, expected + 0.015)


func test_the_split_after_a_caught_lie_uses_honest_needs() -> void:
	var state: RunState = RunState.new(7)
	state.landlord_seat = 1
	state.commons_pool = 1000
	var events: Array[RunEvent] = []
	var caught: Array[int] = []
	var params: RunParams = RunDefaults.PARAMS
	RoundBanking.split(state, 0, 90, RunScript.bots(), params, events, PARAMS.die_sides, caught)
	assert_array(caught).contains([0])
	var honest: PackedInt64Array = Banking.split(
		1000, PackedInt64Array([params.base_need, params.base_need])
	)
	assert_float(state.set_progress).is_equal(float(honest[0]))


## Over 10,000 splits, every bot lies and the player declares above true need. Checked
## declarations come to the faces over the sides within a point and a half, the shares
## paid always equal a split of the needs left standing, and a lone caught liar's share
## falls.
func _simulate(faces: int) -> float:
	var state: RunState = RunState.new(77)
	state.landlord_seat = 1
	var configs: Array[BotConfig] = RunScript.bots()
	for config: BotConfig in configs:
		config.honesty = 0.0
	var params: RunParams = RunDefaults.PARAMS
	var declared: int = 0
	var checked: int = 0
	for index: int in SPLITS:
		state.commons_pool = 10000
		var events: Array[RunEvent] = []
		var caught: Array[int] = []
		RoundBanking.split(state, 0, TRUE_NEED + 20, configs, params, events, faces, caught)
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
	for faces: int in [PARAMS.base_faces, PARAMS.base_faces + PARAMS.informer_faces]:
		var rate: float = _simulate(faces)
		var expected: float = float(faces) / PARAMS.die_sides
		print("faces %d, audited %.4f" % [faces, rate])
		assert_float(rate).is_between(expected - 0.015, expected + 0.015)


## Two lying seats rolled on a stream seeded seed_value, at faces audit faces.
func _roll(seed_value: int, faces: int) -> Array[RunEvent]:
	var events: Array[RunEvent] = []
	var seats: Array[int] = [0, 2]
	var needs: PackedInt64Array = PackedInt64Array([TRUE_NEED + 5, TRUE_NEED + 5])
	var stream: RandomStream = RandomStream.new(seed_value)
	NeedAudit.run(seats, needs, TRUE_NEED, faces, PARAMS.die_sides, stream, events)
	return events

extends GdUnitTestSuite
## P4.5: the village's fourteen families, the roster's states, and the replacement rule
## that keeps two opponents at every Set.

const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const RUNS: int = 10000
const SETS: int = 24
## Harsh odds, far above anything play will cause, so the replacement rule is tested hard.
const HARM_CHANCE: float = 0.2


func test_the_village_has_fourteen_families_eight_at_the_start() -> void:
	assert_int(VILLAGE.families.size()).is_equal(14)
	var starting: int = 0
	for family: FamilyDef in VILLAGE.families:
		if family.unlock == FamilyDef.Unlock.START:
			starting += 1
	assert_int(starting).is_equal(8)
	assert_int(VILLAGE.youth_templates.size()).is_greater(0)
	assert_int(VILLAGE.youth_surnames.size()).is_greater_equal(VILLAGE.opponents * 4)


func test_every_family_is_complete() -> void:
	for family: FamilyDef in VILLAGE.families + VILLAGE.youth_templates:
		var where: String = family.id
		assert_object(family.personality).override_failure_message(where).is_not_null()
		assert_object(family.voice).override_failure_message(where).is_not_null()
		assert_object(family.speech).override_failure_message(where).is_not_null()
		assert_bool(family.speech.lines.is_empty()).override_failure_message(where).is_false()
		# Youth templates take a surname from the pool when they arrive.
		if VILLAGE.families.has(family):
			assert_str(tr(family.name_key)).override_failure_message(where).is_not_equal(
				family.name_key
			)
		for line: SpeechLine in family.speech.lines:
			assert_bool(SpeechBook.EVENTS.has(line.event)).override_failure_message(where).is_true()
			assert_bool(SpeechBook.MOODS.has(line.mood)).override_failure_message(where).is_true()
			assert_str(tr(line.text_key)).override_failure_message(line.text_key).is_not_equal(
				line.text_key
			)
	for key: String in VILLAGE.youth_surnames:
		assert_str(tr(key)).override_failure_message(key).is_not_equal(key)


func test_a_run_starts_with_the_starting_families_and_any_unlocked() -> void:
	var state: RunState = RunState.new(1)
	Roster.start(state, VILLAGE, ["zhou"])
	assert_int(state.roster.size()).is_equal(9)
	assert_object(Roster.entry(state, "zhou")).is_not_null()
	assert_object(Roster.entry(state, "tang")).is_null()


func test_reeducation_returns_after_its_sets() -> void:
	var state: RunState = RunState.new(2)
	Roster.start(state, VILLAGE, [])
	Roster.reeducate(state, "li", VILLAGE)
	var stream: RandomStream = RandomStream.new(2)
	for index: int in VILLAGE.reeducation_sets - 1:
		Roster.prepare_set(state, VILLAGE, stream)
		assert_int(Roster.entry(state, "li").status).is_equal(RosterEntry.Status.REEDUCATION)
		assert_bool(state.table.has("li")).is_false()
	Roster.prepare_set(state, VILLAGE, stream)
	assert_int(Roster.entry(state, "li").status).is_equal(RosterEntry.Status.ACTIVE)


func test_youth_arrive_with_surnames_nobody_holds() -> void:
	var state: RunState = RunState.new(3)
	Roster.start(state, VILLAGE, [])
	for found: RosterEntry in state.roster:
		found.status = RosterEntry.Status.DEAD
	Roster.prepare_set(state, VILLAGE, RandomStream.new(3))
	var youth: Array[RosterEntry] = Roster.available(state)
	assert_int(youth.size()).is_equal(2)
	assert_str(youth[0].name_key).is_not_equal(youth[1].name_key)
	for found: RosterEntry in youth:
		assert_bool(found.template_id.is_empty()).is_false()
		assert_bool(state.table.has(found.family_id)).is_true()


func test_a_rising_family_gains_tiers_as_it_sits() -> void:
	var entry: RosterEntry = RosterEntry.new("gao")
	entry.sets_seated = 1
	var first: BotConfig = Roster.config_for(VILLAGE, entry, 0)
	entry.sets_seated = 1 + VILLAGE.rise_sets * 2
	var later: BotConfig = Roster.config_for(VILLAGE, entry, 0)
	assert_int(later.tier).is_equal(mini(first.tier + 2, BotConfig.Tier.HARD))
	entry.sets_seated = 100
	assert_int(Roster.config_for(VILLAGE, entry, 0).tier).is_equal(BotConfig.Tier.HARD)


## The Done-when check: 10,000 runs of 24 Sets, with harm far harsher than play, and
## never a Set with fewer than two opponents.
func test_10000_runs_never_seat_fewer_than_two_opponents() -> void:
	var short_sets: int = 0
	var harm: RandomStream = RandomStream.new(4500)
	var statuses: Array[RosterEntry.Status] = [
		RosterEntry.Status.DEAD, RosterEntry.Status.DEPOSED, RosterEntry.Status.REEDUCATION
	]
	for run: int in RUNS:
		var state: RunState = RunState.new(run)
		var unlocked: Array[String] = []
		for family: FamilyDef in VILLAGE.families:
			if harm.next_float() < 0.5:
				unlocked.append(family.id)
		Roster.start(state, VILLAGE, unlocked)
		var stream: RandomStream = state.streams.stream(RandomStreams.EVENTS)
		for set_index: int in SETS:
			for found: RosterEntry in Roster.available(state):
				if harm.next_float() < HARM_CHANCE:
					var status: RosterEntry.Status = statuses[harm.next_int(0, statuses.size() - 1)]
					found.status = status
					found.return_timer = VILLAGE.reeducation_sets
			Roster.prepare_set(state, VILLAGE, stream)
			if not _seated_two(state):
				short_sets += 1
	assert_int(short_sets).is_equal(0)


func _seated_two(state: RunState) -> bool:
	if state.table.size() != 3 or state.table[1] == state.table[2]:
		return false
	for seat: int in [1, 2]:
		var found: RosterEntry = Roster.entry(state, state.table[seat])
		if found == null or found.status != RosterEntry.Status.ACTIVE:
			return false
	return true

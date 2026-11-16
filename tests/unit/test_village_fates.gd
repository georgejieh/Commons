extends GdUnitTestSuite
## ADR 0025: a seated family starves at a Quota's end in high Famine, a risen villager
## whose boss Quota is met is deposed until the next Year, and neither touches a boss or
## a run without a roster.

const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const METERS: MeterTable = preload("res://data/run/meters.tres")
const BOSSES: BossPool = preload("res://data/run/boss_pool.tres")


## A roster run at a Quota's end, seating two families, with Famine as given and each
## seated family fed as often as fed says.
func _state(seated: Array[String], fed: Array[int], famine: int) -> RunState:
	var state: RunState = RunState.new(7)
	Roster.start(state, VILLAGE, [])
	state.table = ["player", seated[0], seated[1]]
	state.famine = famine
	var summary: SetSummary = SetSummary.new(0)
	for index: int in seated.size():
		if fed[index] > 0:
			summary.add(seated[index], SetSummary.Kind.FED, fed[index])
	state.summaries.append(summary)
	return state


func _status(state: RunState, family_id: String) -> RosterEntry.Status:
	return Roster.entry(state, family_id).status


func test_the_family_fed_less_starves_in_high_famine() -> void:
	var state: RunState = _state(["li", "chen"], [1, 3], METERS.famine.high)
	var log: SetLog = SetLog.new()
	(
		assert_str(VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, log))
		. is_equal("li")
	)
	assert_int(_status(state, "li")).is_equal(RosterEntry.Status.DEAD)
	assert_int(_status(state, "chen")).is_equal(RosterEntry.Status.ACTIVE)
	var event: RunEvent = log.events()[-1]
	assert_int(event.type).is_equal(RunEvent.Type.STARVED)
	assert_int(event.seat).is_equal(1)
	assert_int(event.value).is_equal(1)
	assert_str(event.text).is_equal("li")


func test_a_tie_takes_the_later_seat() -> void:
	var state: RunState = _state(["li", "chen"], [2, 2], METERS.famine.high + 5)
	(
		assert_str(
			VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
		)
		. is_equal("chen")
	)
	var unfed: RunState = _state(["li", "chen"], [0, 0], METERS.famine.high)
	(
		assert_str(
			VillageFates.starve(unfed, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
		)
		. is_equal("chen")
	)


func test_nobody_starves_below_the_high_band_or_at_death() -> void:
	for famine: int in [0, METERS.famine.mid, METERS.famine.high - 1, METERS.famine.death]:
		var state: RunState = _state(["li", "chen"], [0, 3], famine)
		(
			assert_str(
				VillageFates.starve(
					state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new()
				)
			)
			. is_empty()
		)
		assert_int(_status(state, "li")).is_equal(RosterEntry.Status.ACTIVE)


func test_a_boss_never_starves() -> void:
	var state: RunState = _state(["li", "chen"], [0, 5], METERS.famine.high)
	state.boss_id = BOSSES.risen.id
	state.boss_family = "li"
	(
		assert_str(
			VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
		)
		. is_equal("chen")
	)
	assert_int(_status(state, "li")).is_equal(RosterEntry.Status.ACTIVE)


func test_a_run_without_a_roster_loses_nobody() -> void:
	var state: RunState = RunState.new(7)
	state.famine = METERS.famine.high
	state.summaries.append(SetSummary.new(0))
	(
		assert_str(
			VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
		)
		. is_empty()
	)


## The dead never sit again; when too few are left, a sent-down youth takes the seat.
func test_the_dead_are_never_seated_and_youth_fill_in() -> void:
	var state: RunState = _state(["li", "chen"], [0, 1], METERS.famine.high)
	VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
	for entry: RosterEntry in state.roster:
		if entry.family_id != "chen":
			entry.status = RosterEntry.Status.DEAD
	var stream: RandomStream = RandomStream.new(3)
	Roster.prepare_set(state, VILLAGE, stream)
	assert_bool(state.table.has("li")).is_false()
	assert_bool(state.table.has("chen")).is_true()
	var youth: String = state.table[1] if state.table[2] == "chen" else state.table[2]
	assert_str(youth).starts_with(Roster.YOUTH_PREFIX)


## An ending that names the dead names the family that starved.
func test_the_ending_names_the_dead() -> void:
	var state: RunState = _state(["li", "chen"], [0, 1], METERS.famine.high)
	VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
	var lines: Array[EpilogueLine] = Endings.epilogue(
		state, Endings.LEAN_YEARS, VILLAGE, RunLoop.DEFAULT_MEMORY
	)
	var named: Array[String] = []
	for line: EpilogueLine in lines:
		if line.key == Endings.MISSING_KEY:
			named = line.name_keys
		assert_bool(line.family_ids.has("li")).is_false()
	assert_array(named).contains_exactly(["villager.li"])


## Two high-Famine Quotas in one Year take one family; the next Year may take another.
func test_at_most_one_family_starves_a_year() -> void:
	var state: RunState = _state(["li", "chen"], [0, 1], METERS.famine.high)
	var per_year: int = VILLAGE.starvations_per_year
	assert_int(per_year).is_equal(1)
	assert_str(VillageFates.starve(state, METERS.famine, per_year, SetLog.new())).is_equal("li")
	assert_int(state.year_starved).is_equal(1)
	state.table = ["player", "gao", "chen"]
	state.summaries.append(SetSummary.new(1))
	assert_str(VillageFates.starve(state, METERS.famine, per_year, SetLog.new())).is_empty()
	assert_int(_status(state, "gao")).is_equal(RosterEntry.Status.ACTIVE)
	VillageFates.new_year(state, SetLog.new())
	assert_int(state.year_starved).is_equal(0)
	assert_str(VillageFates.starve(state, METERS.famine, per_year, SetLog.new())).is_equal("chen")


## The Year's count is saved, so a reload mid-Year does not open the way to a second death.
func test_the_years_count_survives_save_and_load() -> void:
	var state: RunState = _state(["li", "chen"], [0, 1], METERS.famine.high)
	VillageFates.starve(state, METERS.famine, VILLAGE.starvations_per_year, SetLog.new())
	var record: RunRecord = RunRecord.new()
	record.mark(state)
	var data: Dictionary = record.to_dict()
	assert_bool(RunRecord.is_valid(data)).is_true()
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_int(loaded.year_starved).is_equal(1)
	loaded.table = ["player", "gao", "chen"]
	var per_year: int = VILLAGE.starvations_per_year
	assert_str(VillageFates.starve(loaded, METERS.famine, per_year, SetLog.new())).is_empty()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint["year_starved"] = -1
	assert_bool(RunRecord.is_valid(data)).is_false()
	checkpoint.erase("year_starved")
	checkpoint.erase("identity")
	var migrated: Dictionary = RunRecord.migrate_from_10(data)
	var migrated_checkpoint: Dictionary = migrated["checkpoint"]
	assert_int(int(migrated_checkpoint["year_starved"])).is_equal(0)
	assert_bool(RunRecord.is_valid(migrated)).is_true()


func test_a_met_quota_deposes_the_risen_boss_until_the_next_year() -> void:
	var state: RunState = _state(["li", "chen"], [0, 0], 0)
	state.boss_id = BOSSES.risen.id
	state.boss_family = "li"
	var log: SetLog = SetLog.new()
	assert_str(VillageFates.depose(state, BOSSES.risen.id, log)).is_equal("li")
	assert_int(_status(state, "li")).is_equal(RosterEntry.Status.DEPOSED)
	assert_int(log.events()[-1].type).is_equal(RunEvent.Type.DEPOSED)
	assert_bool(VillageFates.is_gone(state, "li")).is_true()
	assert_bool(Roster.available(state).any(_is.bind("li"))).is_false()
	VillageFates.new_year(state, log)
	assert_int(_status(state, "li")).is_equal(RosterEntry.Status.ACTIVE)
	assert_bool(VillageFates.is_gone(state, "li")).is_false()


func test_only_a_risen_villager_is_deposed() -> void:
	var state: RunState = _state(["li", "chen"], [0, 0], 0)
	state.boss_id = BOSSES.officials[0].id
	assert_str(VillageFates.depose(state, BOSSES.risen.id, SetLog.new())).is_empty()
	for entry: RosterEntry in state.roster:
		assert_int(entry.status).is_equal(RosterEntry.Status.ACTIVE)


## A deposed family has run its boss Set, so the boss pool never offers it again this
## run, even once it is back in the village.
func test_a_deposed_family_leaves_the_boss_pool_for_the_run() -> void:
	var state: RunState = _state(["li", "chen"], [0, 0], 0)
	state.risen.assign(["li"])
	state.year = 2
	var stream: RandomStream = RandomStream.new(5)
	assert_object(Bosses.choose(state, BOSSES, 8, stream)).is_same(BOSSES.risen)
	state.boss_id = BOSSES.risen.id
	assert_str(VillageFates.depose(state, BOSSES.risen.id, SetLog.new())).is_equal("li")
	VillageFates.new_year(state, SetLog.new())
	state.year = 4
	state.boss_family = ""
	assert_object(Bosses.choose(state, BOSSES, 8, stream)).is_not_same(BOSSES.risen)
	assert_str(state.boss_family).is_empty()


func _is(entry: RosterEntry, family_id: String) -> bool:
	return entry.family_id == family_id

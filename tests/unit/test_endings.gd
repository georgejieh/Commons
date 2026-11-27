extends GdUnitTestSuite
## ADR 0024: the class from the Year's counters, the six endings and The Commons, both
## deaths, ties, and each family's one epilogue line by its state and its memory.

const METERS: MeterTable = preload("res://data/run/meters.tres")
const PARAMS: EndingParams = preload("res://data/run/endings.tres")
const MEMORY: MemoryParams = preload("res://data/villagers/memory.tres")
const BOOK: VillageBook = preload("res://data/villagers/village.tres")


## A finished run: class from the counters, the meters and Resentment as given.
func _state(landlord_rounds: int, famine: int, denunciation: int, resentment: int = 40) -> RunState:
	var state: RunState = RunState.new(1)
	state.phase = RunFlow.State.RUN_END
	state.year = 8
	state.year_rounds = 4
	state.year_landlord_rounds = landlord_rounds
	state.famine = famine
	state.denunciation = denunciation
	state.resentment = resentment
	return state


func _roster(state: RunState, ids: Array[String]) -> void:
	for family_id: String in ids:
		state.roster.append(RosterEntry.new(family_id))


func _outcome(state: RunState) -> String:
	return Endings.outcome(state, METERS, PARAMS)


func test_the_class_is_landlord_from_half_the_years_rounds() -> void:
	var state: RunState = RunState.new(1)
	assert_bool(YearClass.is_landlord(state)).is_false()
	for landlord: int in [0, 0, 0, 0]:
		YearClass.count_round(state, landlord, 0)
	assert_bool(YearClass.is_landlord(state)).is_true()
	state = _state(2, 0, 0)
	assert_bool(YearClass.is_landlord(state)).override_failure_message("exactly half").is_true()
	state.year_landlord_rounds = 1
	assert_bool(YearClass.is_landlord(state)).is_false()
	YearClass.new_year(state)
	assert_int(state.year_rounds).is_equal(0)
	assert_int(state.year_landlord_rounds).is_equal(0)
	assert_bool(YearClass.is_landlord(state)).is_false()


func test_every_ending_is_reached() -> void:
	var high: int = METERS.famine.high
	var mid: int = METERS.famine.mid
	assert_str(_outcome(_state(0, mid, 0))).is_equal(Endings.SECRET_CONTRACT)
	assert_str(_outcome(_state(0, 0, 0, PARAMS.collective_resentment))).is_equal(
		Endings.THE_COMMONS
	)
	assert_str(_outcome(_state(0, high, 0))).is_equal(Endings.LEAN_YEARS)
	assert_str(_outcome(_state(0, 0, high))).is_equal(Endings.LABELED)
	assert_str(_outcome(_state(2, 0, 0))).is_equal(Endings.BENEVOLENT_LANDLORD)
	assert_str(_outcome(_state(3, high, 0))).is_equal(Endings.FULL_GRANARY)
	assert_str(_outcome(_state(4, 0, high))).is_equal(Endings.STRUGGLED)


func test_the_commons_is_just_missed_by_one_resentment_or_a_meter_at_mid() -> void:
	var low: int = PARAMS.collective_resentment
	assert_str(_outcome(_state(0, 0, 0, low + 1))).is_equal(Endings.SECRET_CONTRACT)
	assert_str(_outcome(_state(0, METERS.famine.mid, 0, low))).is_equal(Endings.SECRET_CONTRACT)
	assert_str(_outcome(_state(0, 0, METERS.denunciation.mid, low))).is_equal(
		Endings.SECRET_CONTRACT
	)
	(
		assert_str(_outcome(_state(0, METERS.famine.mid - 1, METERS.denunciation.mid - 1, low)))
		. is_equal(Endings.THE_COMMONS)
	)
	# A landlord never earns the collective variant.
	assert_str(_outcome(_state(2, 0, 0, 0))).is_equal(Endings.BENEVOLENT_LANDLORD)


func test_both_meters_high_the_larger_decides_and_denunciation_a_tie() -> void:
	var high: int = METERS.famine.high
	assert_str(_outcome(_state(0, high + 5, high))).is_equal(Endings.LEAN_YEARS)
	assert_str(_outcome(_state(0, high, high + 5))).is_equal(Endings.LABELED)
	assert_str(_outcome(_state(0, high, high))).is_equal(Endings.LABELED)
	assert_str(_outcome(_state(4, high, high))).is_equal(Endings.STRUGGLED)
	assert_str(_outcome(_state(4, high + 1, high))).is_equal(Endings.FULL_GRANARY)


func test_both_deaths_and_denunciation_first_when_both_are_at_death() -> void:
	var death: int = METERS.famine.death
	assert_str(_outcome(_state(0, death, 0))).is_equal(Endings.DEATH_FAMINE)
	assert_str(_outcome(_state(4, 0, death))).is_equal(Endings.DEATH_DENUNCIATION)
	assert_str(_outcome(_state(0, death, death))).is_equal(Endings.DEATH_DENUNCIATION)
	var state: RunState = _state(0, death, 0)
	_roster(state, ["wang", "li"])
	assert_array(Endings.epilogue(state, Endings.DEATH_FAMINE, BOOK, MEMORY, PARAMS)).is_empty()
	assert_bool(Endings.is_death(Endings.DEATH_FAMINE)).is_true()
	assert_str(Endings.title_key(Endings.DEATH_FAMINE)).is_equal("death.famine.title")
	assert_str(Endings.text_key(Endings.DEATH_DENUNCIATION)).is_equal("death.denunciation.text")


## Every family not dead is named in exactly one line, no two lines share a key, and the
## lines run in the roster order of each one's first family.
func test_every_family_not_dead_is_named_in_exactly_one_line() -> void:
	for ending_id: String in Endings.ENDINGS:
		var state: RunState = _state(0, 0, 0)
		var ids: Array[String] = []
		for family: FamilyDef in BOOK.families:
			ids.append(family.id)
		_roster(state, ids)
		state.roster[3].status = RosterEntry.Status.DEAD
		state.roster[7].status = RosterEntry.Status.DEAD
		state.roster[5].status = RosterEntry.Status.REEDUCATION
		state.roster[9].status = RosterEntry.Status.DEPOSED
		_add(state.memory, ids[2], SetSummary.Kind.FED, 3.0)
		_add(state.memory, ids[4], SetSummary.Kind.DENOUNCED, 3.0)
		var lines: Array[EpilogueLine] = Endings.epilogue(state, ending_id, BOOK, MEMORY, PARAMS)
		var families: Array[String] = []
		var keys: Array[String] = []
		var firsts: Array[int] = []
		for line: EpilogueLine in lines:
			assert_bool(keys.has(line.key)).override_failure_message(ending_id).is_false()
			keys.append(line.key)
			assert_int(line.name_keys.size()).is_greater(0)
			if line.key == Endings.MISSING_KEY:
				continue
			assert_int(line.family_ids.size()).is_equal(line.name_keys.size())
			firsts.append(ids.find(line.family_ids[0]))
			families.append_array(line.family_ids)
		var living: Array[String] = ids.filter(
			func(id: String) -> bool: return id != ids[3] and id != ids[7]
		)
		families.sort_custom(func(a: String, b: String) -> bool: return ids.find(a) < ids.find(b))
		assert_array(families).override_failure_message(ending_id).is_equal(living)
		var ordered: Array[int] = firsts.duplicate()
		ordered.sort()
		assert_array(firsts).override_failure_message(ending_id).is_equal(ordered)
		# Warm, wary, bitter, reeducation and deposed: five lines for twelve families.
		var roll_call: bool = Endings.ROLL_CALL.has(ending_id)
		assert_int(lines.size()).is_equal(5 + (1 if roll_call else 0))
		if roll_call:
			assert_str(lines[-1].key).is_equal(Endings.MISSING_KEY)
			var dead: Array[String] = [BOOK.families[3].name_key, BOOK.families[7].name_key]
			assert_array(lines[-1].name_keys).is_equal(dead)


## Names on one line join with commas and "and", through the string table.
func test_names_join_with_commas_and_and() -> void:
	assert_str(EndingView.joined(PackedStringArray())).is_empty()
	assert_str(EndingView.joined(PackedStringArray(["Sun"]))).is_equal("Sun")
	assert_str(EndingView.joined(PackedStringArray(["Sun", "Gao"]))).is_equal("Sun and Gao")
	var three: PackedStringArray = PackedStringArray(["Sun", "Gao", "Ma"])
	assert_str(EndingView.joined(three)).is_equal("Sun, Gao and Ma")
	var line: String = tr("epilogue.secret_contract.wary").format(
		{"name": EndingView.joined(three)}
	)
	assert_str(line).is_equal("Sun, Gao and Ma signed last.")


## Families on one line keep roster order among themselves.
func test_families_on_one_line_keep_roster_order() -> void:
	var state: RunState = _state(0, 0, 0)
	_roster(state, ["wang", "li", "sun", "chen"])
	_add(state.memory, "li", SetSummary.Kind.FED, 3.0)
	var lines: Array[EpilogueLine] = Endings.epilogue(state, Endings.LABELED, BOOK, MEMORY, PARAMS)
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0].key).is_equal("epilogue.labeled.wary")
	assert_array(lines[0].family_ids).is_equal(["wang", "sun", "chen"])
	assert_array(lines[1].family_ids).is_equal(["li"])


func test_the_state_lines_replace_the_ending_line() -> void:
	var state: RunState = _state(0, 0, 0)
	_roster(state, ["wang", "li", "sun"])
	state.roster[0].status = RosterEntry.Status.REEDUCATION
	state.roster[1].status = RosterEntry.Status.DEPOSED
	var lines: Array[EpilogueLine] = Endings.epilogue(state, Endings.STRUGGLED, BOOK, MEMORY)
	assert_str(lines[0].key).is_equal(Endings.REEDUCATION_KEY)
	assert_str(lines[1].key).is_equal(Endings.DEPOSED_KEY)
	assert_str(lines[2].key).is_equal("epilogue.struggled.wary")
	assert_array(lines[0].name_keys).is_equal(["villager.wang"])


func test_dispositions_at_their_boundaries() -> void:
	var memory: VillageMemory = VillageMemory.new()
	assert_str(Endings.disposition(memory, "wang", MEMORY, PARAMS)).is_equal(Endings.WARY)
	# Fed once and bombed once: a bomb weighs more, so a grudge remains, and that is wary.
	_add(memory, "li", SetSummary.Kind.FED, 1.0)
	_add(memory, "li", SetSummary.Kind.BOMBED, 1.0)
	assert_str(Endings.disposition(memory, "li", MEMORY, PARAMS)).is_equal(Endings.WARY)
	# Fed twice and bombed once is exactly even, which is not warm; a little more is.
	_add(memory, "zhao", SetSummary.Kind.FED, 2.0)
	_add(memory, "zhao", SetSummary.Kind.BOMBED, 1.0)
	assert_str(Endings.disposition(memory, "zhao", MEMORY, PARAMS)).is_equal(Endings.WARY)
	_add(memory, "zhao", SetSummary.Kind.FED, 0.5)
	assert_str(Endings.disposition(memory, "zhao", MEMORY, PARAMS)).is_equal(Endings.WARM)
	# A pull of exactly bitter_pull is bitter; just under it is wary.
	var full: float = MEMORY.full_grudge * PARAMS.bitter_pull
	_add(memory, "sun", SetSummary.Kind.BETRAYED, full / MEMORY.betrayed_weight)
	assert_str(Endings.disposition(memory, "sun", MEMORY, PARAMS)).is_equal(Endings.BITTER)
	_add(memory, "chen", SetSummary.Kind.BETRAYED, full / MEMORY.betrayed_weight - 0.01)
	assert_str(Endings.disposition(memory, "chen", MEMORY, PARAMS)).is_equal(Endings.WARY)


func test_the_line_follows_the_disposition() -> void:
	var state: RunState = _state(0, 0, 0)
	_roster(state, ["wang", "li", "sun"])
	_add(state.memory, "wang", SetSummary.Kind.FED, 3.0)
	_add(state.memory, "sun", SetSummary.Kind.DENOUNCED, 3.0)
	var lines: Array[EpilogueLine] = Endings.epilogue(state, Endings.LABELED, BOOK, MEMORY, PARAMS)
	assert_str(lines[0].key).is_equal("epilogue.labeled.warm")
	assert_str(lines[1].key).is_equal("epilogue.labeled.wary")
	assert_str(lines[2].key).is_equal("epilogue.labeled.bitter")


func test_the_dead_line_only_on_the_two_endings_and_only_with_someone_dead() -> void:
	var state: RunState = _state(0, 0, 0)
	_roster(state, ["wang", "li"])
	for ending_id: String in Endings.ENDINGS:
		var lines: Array[EpilogueLine] = Endings.epilogue(state, ending_id, BOOK, MEMORY, PARAMS)
		# Both wary, so both on one line.
		assert_int(lines.size()).override_failure_message(ending_id).is_equal(1)
		assert_int(lines[0].name_keys.size()).is_equal(2)
	state.roster[1].status = RosterEntry.Status.DEAD
	for ending_id: String in Endings.ENDINGS:
		var lines: Array[EpilogueLine] = Endings.epilogue(state, ending_id, BOOK, MEMORY, PARAMS)
		var named: bool = lines.any(
			func(line: EpilogueLine) -> bool: return line.key == Endings.MISSING_KEY
		)
		assert_bool(named).override_failure_message(ending_id).is_equal(
			Endings.ROLL_CALL.has(ending_id)
		)


func test_an_empty_roster_and_an_all_dead_one() -> void:
	var state: RunState = _state(0, METERS.famine.high, 0)
	assert_array(Endings.epilogue(state, Endings.LEAN_YEARS, BOOK, MEMORY, PARAMS)).is_empty()
	_roster(state, ["wang", "li"])
	for entry: RosterEntry in state.roster:
		entry.status = RosterEntry.Status.DEAD
	var lines: Array[EpilogueLine] = Endings.epilogue(state, Endings.LEAN_YEARS, BOOK, MEMORY)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0].key).is_equal(Endings.MISSING_KEY)
	assert_array(Endings.epilogue(state, Endings.LABELED, BOOK, MEMORY, PARAMS)).is_empty()


func test_a_sent_down_youth_is_named_by_the_surname_it_arrived_with() -> void:
	var state: RunState = _state(0, 0, 0)
	var youth: RosterEntry = RosterEntry.new("youth_0")
	youth.template_id = BOOK.youth_templates[0].id
	youth.name_key = "villager.youth.hu"
	state.roster.append(youth)
	var lines: Array[EpilogueLine] = Endings.epilogue(state, Endings.LABELED, BOOK, MEMORY)
	assert_array(lines[0].name_keys).is_equal(["villager.youth.hu"])


func test_working_out_the_ending_never_changes_the_state() -> void:
	var state: RunState = _state(0, METERS.famine.high, 0)
	_roster(state, ["wang", "li", "sun", "chen"])
	state.roster[1].status = RosterEntry.Status.DEAD
	state.roster[2].status = RosterEntry.Status.REEDUCATION
	_add(state.memory, "wang", SetSummary.Kind.FED, 3.0)
	var was: Dictionary = state.to_dict()
	var ending_id: String = Endings.outcome(state, METERS, PARAMS)
	Endings.epilogue(state, ending_id, BOOK, MEMORY, PARAMS)
	for family: String in ["wang", "li", "sun", "chen", "nobody"]:
		Endings.disposition(state.memory, family, MEMORY, PARAMS)
	assert_dict(state.to_dict()).is_equal(was)


func test_every_key_the_endings_use_is_in_the_string_table() -> void:
	var known: Dictionary[String, bool] = {}
	var table: FileAccess = FileAccess.open("res://data/strings/strings.csv", FileAccess.READ)
	while not table.eof_reached():
		var row: PackedStringArray = table.get_csv_line()
		if not row.is_empty():
			known[row[0]] = true
	var missing: Array[String] = []
	for key: String in Endings.keys():
		if not known.has(key):
			missing.append(key)
	assert_array(missing).is_empty()
	assert_int(Endings.keys().size()).is_equal(7 * 2 + 2 * 2 + 7 * 3 + 4)


func _add(memory: VillageMemory, family_id: String, kind: SetSummary.Kind, amount: float) -> void:
	if not memory.counts.has(family_id):
		var row: PackedFloat64Array = []
		row.resize(SetSummary.Kind.size())
		memory.counts[family_id] = row
	memory.counts[family_id][kind] += amount

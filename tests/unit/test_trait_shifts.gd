extends GdUnitTestSuite
## Trait shifts (ADR 0043): Qin's honesty falls to Low while Famine stands in its high band
## and is back at its own once Famine falls below it. The claims Qin makes on either side
## of the band are golden, and every family's shifts name a real meter, trait and line.

const VILLAGE: VillageBook = preload("res://data/villagers/village.tres")
const SEED: int = 4307
const CLAIMS: int = 12
## Qin's claims, from SEED's stream, with Famine one under the high band and at it. The
## fair half is the run's base need, 10: below the band a lie adds half of it, at the band
## the whole of it, and more of the claims are lies.
const GOLDEN_BELOW: Array[int] = [15, 10, 15, 15, 15, 10, 15, 10, 10, 10, 10, 10]
const GOLDEN_AT: Array[int] = [20, 10, 20, 20, 20, 20, 20, 10, 20, 10, 20, 10]


func _qin_run(famine: int) -> RunState:
	var state: RunState = RunState.new(SEED)
	Roster.start(state, VILLAGE, [])
	state.roster = state.roster.filter(
		func(found: RosterEntry) -> bool: return found.family_id in ["qin", "wang"]
	)
	state.table.assign([RunState.DEFAULT_TABLE[0], "qin", "wang"])
	state.famine = famine
	return state


func _configs() -> Array[BotConfig]:
	var configs: Array[BotConfig] = [BotConfig.new()]
	for family_id: String in ["qin", "wang"]:
		configs.append(BotConfig.from_personality(VILLAGE.family(family_id).personality))
	return configs


func _claims(famine: int) -> Array[int]:
	var state: RunState = _qin_run(famine)
	var configs: Array[BotConfig] = _configs()
	TraitShifts.apply(state, configs, VILLAGE, RunLoop.DEFAULT_METERS)
	var stream: RandomStream = RandomStream.new(SEED)
	var fair: int = RunLoop.DEFAULT_PARAMS.base_need
	var claims: Array[int] = []
	for _claim: int in CLAIMS:
		claims.append(Bot.declare_need(fair, configs[1], stream, BotBudget.unlimited()))
	return claims


func test_qin_carries_one_shift_of_honesty_at_famines_high_band() -> void:
	var shifts: Array[TraitShift] = VILLAGE.family("qin").shifts
	assert_int(shifts.size()).is_equal(1)
	assert_str(shifts[0].meter).is_equal(RunMeters.FAMINE)
	assert_int(shifts[0].band).is_equal(MeterBands.Band.HIGH)
	assert_str(shifts[0].trait_name).is_equal(TraitShifts.HONESTY)
	assert_int(shifts[0].level).is_equal(Personality.Level.LOW)


func test_every_familys_shifts_name_a_real_meter_trait_and_line() -> void:
	for family: FamilyDef in VILLAGE.families + VILLAGE.youth_templates:
		for shift: TraitShift in family.shifts:
			assert_bool([RunMeters.FAMINE, RunMeters.DENUNCIATION].has(shift.meter)).is_true()
			assert_bool(VillageDrift.TRAITS.has(shift.trait_name)).is_true()
			assert_str(tr(shift.seen_key)).is_not_equal(shift.seen_key)


func test_qins_honesty_falls_at_the_band_and_returns_below_it() -> void:
	var high: int = RunLoop.DEFAULT_METERS.famine.high
	var table: PersonalityTable = BotConfig.TABLE
	for case: Array in [[high - 1, Personality.Level.MID], [high, Personality.Level.LOW]]:
		var state: RunState = _qin_run(case[0])
		var configs: Array[BotConfig] = _configs()
		var shifted: Array[int] = TraitShifts.apply(state, configs, VILLAGE, RunLoop.DEFAULT_METERS)
		assert_float(configs[1].honesty).is_equal_approx(table.honesty[case[1]], 1e-6)
		assert_float(configs[1].lie_share).is_equal_approx(table.lie_share[case[1]], 1e-6)
		assert_array(shifted).is_equal([1] if case[1] == Personality.Level.LOW else [])
		# Wang carries no shift and keeps the config the run made.
		assert_float(configs[2].honesty).is_equal_approx(
			table.honesty[Personality.Level.HIGH], 1e-6
		)
	# Once Famine falls back under the band, Qin's own honesty is back on the same config.
	var state: RunState = _qin_run(high)
	var configs: Array[BotConfig] = _configs()
	TraitShifts.apply(state, configs, VILLAGE, RunLoop.DEFAULT_METERS)
	state.famine = high - 1
	TraitShifts.apply(state, configs, VILLAGE, RunLoop.DEFAULT_METERS)
	assert_float(configs[1].honesty).is_equal_approx(table.honesty[Personality.Level.MID], 1e-6)


func test_qins_claims_either_side_of_the_band_are_golden() -> void:
	var high: int = RunLoop.DEFAULT_METERS.famine.high
	assert_array(_claims(high - 1)).is_equal(GOLDEN_BELOW)
	assert_array(_claims(high)).is_equal(GOLDEN_AT)


## Drift moves a family's own level; while the shift holds, the shift's level stands in
## its place, and below the band the drifted level is what Qin plays by.
func test_the_shift_stands_over_drift_and_drift_returns_below_the_band() -> void:
	var high: int = RunLoop.DEFAULT_METERS.famine.high
	var state: RunState = _qin_run(high - 1)
	state.drift = VillageDrift.new()
	state.drift.levels["qin"] = {TraitShifts.HONESTY: 1}
	var configs: Array[BotConfig] = _configs()
	TraitShifts.apply(state, configs, VILLAGE, RunLoop.DEFAULT_METERS)
	var table: PersonalityTable = BotConfig.TABLE
	assert_float(configs[1].honesty).is_equal_approx(table.honesty[Personality.Level.HIGH], 1e-6)
	state.famine = high
	TraitShifts.apply(state, configs, VILLAGE, RunLoop.DEFAULT_METERS)
	assert_float(configs[1].honesty).is_equal_approx(table.honesty[Personality.Level.LOW], 1e-6)

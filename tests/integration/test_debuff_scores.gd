extends GdUnitTestSuite
## The scoring, economy and meter debuffs of ADR 0023 at the table, through RunLoop: Short
## Supply, Slogan of the Week, Work-Point Audit, Grain Tax, Overtime, Big-Character Poster
## and Hungry Winter. Each is put in force from round 2 (index 1) by hand, so it applies
## in every later round of the Set.

const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const IN_FORCE: Array[int] = [1, 2, 3]


## The player's result in each round: who won, what they banked, and what was cut.
func _results(loop: RunLoop) -> Array[Dictionary]:
	var rounds: Array[Dictionary] = []
	var current: Dictionary = {}
	for event: RunEvent in loop.events():
		match event.type:
			RunEvent.Type.ROUND:
				var played: RoundEvent = event.round_event
				if played.type == RoundEvent.Type.ROUND_STARTED:
					current = {"landlord": played.seat, "share": 0, "taxed": 0.0, "voided": 0.0}
				elif played.type == RoundEvent.Type.ROUND_ENDED:
					current["lost"] = (
						(played.seat == current["landlord"]) != (current["landlord"] == 0)
					)
			RunEvent.Type.BANKED:
				current["banked"] = event.amount
			RunEvent.Type.SHARE_PAID:
				if event.seat == RunLoop.PLAYER:
					current["share"] = event.value
			RunEvent.Type.GRAIN_TAXED:
				current["taxed"] = event.amount
			RunEvent.Type.BANK_VOIDED:
				current["voided"] = event.amount
			RunEvent.Type.SEAT_KEPT, RunEvent.Type.SEAT_LOST:
				rounds.append(current)
	return rounds


func test_short_supply_cuts_a_cadre_from_the_next_store_and_stacks_with_rationing() -> void:
	for rationed: bool in [false, true]:
		var loop: RunLoop = DebuffScript.loop_with(5, "short_supply")
		DebuffScript.play(loop)
		loop.state.rationed = rationed
		assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
		var ration: int = RunDefaults.METERS.rationing_shop_cut if rationed else 0
		assert_int(loop.visit.shop.short_cut).is_equal(1)
		assert_int(loop.visit.shop.slot_count()).is_equal(STORE.slots - 1 - ration)
		assert_int(loop.visit.shop.stock().size()).is_equal(STORE.slots - 1 - ration)
		# The black market's counter is not the state store.
		assert_int(loop.visit.market.short_cut).is_equal(0)


## A Short Supply drawn for a round the Quota never reached never came into force.
func test_short_supply_counts_only_once_it_came_into_force() -> void:
	var state: RunState = RunState.new(1)
	state.debuff_ladder.assign(["", "", "", "short_supply"])
	var known: Dictionary[String, ModifierDef] = {
		"short_supply": DebuffScript.definition("short_supply")
	}
	state.round_index = 3
	assert_int(RunDebuffs.store_cut(state, known, RunLoop.PLAYER)).is_equal(0)
	state.round_index = 4
	assert_int(RunDebuffs.store_cut(state, known, RunLoop.PLAYER)).is_equal(1)


func test_the_slogan_halves_its_hand_types_rate_rounded_up_for_you_alone() -> void:
	var loop: RunLoop = DebuffScript.loop_with(13, "slogan_of_the_week")
	loop.state.slogan_type = Pattern.Type.PAIR
	DebuffScript.play(loop)
	var round_index: int = 0
	var played: RoundEvent = null
	var halved: Array[int] = []
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.SEAT_KEPT or event.type == RunEvent.Type.SEAT_LOST:
			round_index += 1
		if event.round_event != null and event.round_event.type == RoundEvent.Type.PLAYED:
			played = event.round_event
		if event.type != RunEvent.Type.PLAY_SCORED:
			continue
		var level: int = loop.state.hand_levels.level_of(played.pattern.type)
		var rate: float = Scorer.DEFAULT_PARAMS.rate_for(played.pattern.type, level)
		var named: bool = played.pattern.type == Pattern.Type.PAIR
		if named and played.seat == RunLoop.PLAYER and round_index >= 1:
			rate = ceilf(rate / 2.0)
			halved.append(round_index)
		assert_float(event.rate).is_equal(rate)
	assert_int(halved.size()).is_greater(0)
	# Its name and rules say which hand type it named.
	var controller: RunController = auto_free(RunController.new())
	controller.resume(loop)
	assert_str(controller.texts.modifier_name("slogan_of_the_week")).is_equal(
		"Slogan of the Week: Pairs"
	)
	assert_str(controller.texts.modifier_text("slogan_of_the_week")).contains(
		"Your Pairs score at 50%"
	)


## The Rate is halved first; a cap such as Iron Rice Bowl's applies after.
func test_the_slogan_halves_before_any_rate_cap() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var bowl: ModifierDef = load("res://data/modifiers/iron_rice_bowl.tres")
	stack.add(bowl, RunLoop.PLAYER)
	var slogan: ActiveModifier = stack.add(
		DebuffScript.definition("slogan_of_the_week"), RunLoop.PLAYER
	)
	slogan.effect.parameters[SloganEffect.TYPE] = Pattern.Type.BOMB
	var cards: Array[CardInstance] = []
	for deck_id: int in [0, 1, 2, 3]:
		cards.append(Deck.new().card(deck_id))
	var bomb: Pattern = (
		Classifier
		. classify(RankText.counts("3333"), RuleSet.default_rules(), Ranks.identity_map())
		. pattern
	)
	var scored: ScoreBreakdown = Scorer.score_play(cards, bomb, 1, RunLoop.PLAYER, false, stack)
	var base: float = Scorer.DEFAULT_PARAMS.rate_for(Pattern.Type.BOMB, 1)
	var cap: float = bowl.parameters["rate_cap"]
	assert_bool(base > cap and ceilf(base / 2.0) < cap).is_true()
	assert_float(scored.rate).is_equal(ceilf(base / 2.0))


## The hand type is drawn with the ladder, after it, and is never the Rocket.
func test_the_slogans_hand_type_is_drawn_with_the_ladder_and_never_rocket() -> void:
	var types: Dictionary[int, bool] = {}
	for seed_value: int in 300:
		var stream: RandomStream = RandomStream.new(seed_value)
		var ladder: Array[String] = ["", "slogan_of_the_week"]
		var type: int = RunDebuffs.draw_slogan(ladder, stream)
		assert_bool(type >= Pattern.Type.SINGLE and type <= Pattern.Type.BOMB).is_true()
		types[type] = true
		var none: Array[String] = ["", "levy"]
		assert_int(RunDebuffs.draw_slogan(none, stream)).is_equal(RunState.NO_SLOGAN)
	assert_int(types.size()).is_equal(Pattern.Type.BOMB)


func test_work_point_audit_adds_two_audit_faces_for_every_claim() -> void:
	var loop: RunLoop = DebuffScript.loop_with(17, "work_point_audit")
	DebuffScript.play(loop)
	var rolls: Dictionary[int, Array] = DebuffScript.per_round(loop, RunEvent.Type.AUDIT_ROLLED)
	var audit: AuditParams = RunPools.AUDIT
	for round_index: int in rolls:
		var faces: int = audit.base_faces + (2 if round_index >= 1 else 0)
		for roll: RunEvent in rolls[round_index]:
			assert_float(roll.amount).is_equal(float(faces))
	assert_bool(rolls.has(1) or rolls.has(2) or rolls.has(3)).is_true()
	var players: int = 0
	for round_index: int in rolls:
		for roll: RunEvent in rolls[round_index]:
			players += 1 if roll.seat == RunLoop.PLAYER else 0
	assert_int(players).is_greater(0)


## ADR 0021's cap holds: never more than max_faces audit, so a check is never certain.
func test_work_point_audit_stays_under_the_audit_cap() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(DebuffScript.definition("work_point_audit"), RunLoop.PLAYER)
	var params: AuditParams = RunPools.AUDIT.duplicate()
	var state: RunState = RunState.new(1)
	state.table.assign(["player", "zhou", "seat_2"])
	assert_int(NeedAudit.faces(state, params, stack)).is_equal(4)
	params.base_faces = 3
	assert_int(NeedAudit.faces(state, params, stack)).is_equal(params.max_faces)
	assert_bool(params.max_faces < params.die_sides).is_true()


func test_grain_tax_takes_a_fifth_of_what_you_bank_rounded_against_you() -> void:
	var loop: RunLoop = DebuffScript.loop_with(19, "grain_tax")
	DebuffScript.play(loop)
	var results: Array[Dictionary] = _results(loop)
	var progress: float = 0.0
	var taxed: int = 0
	for round_index: int in results.size():
		var result: Dictionary = results[round_index]
		var landlord: bool = result["landlord"] == RunLoop.PLAYER
		var kept: float = float(result["banked"]) if landlord else float(result["share"])
		var was: float = kept + float(result["taxed"]) if landlord else kept
		if round_index == 0 or was <= 0.0:
			assert_float(float(result["taxed"])).is_equal(0.0)
		else:
			assert_float(float(result["taxed"])).is_equal(ceilf(was * 20 / 100.0))
			taxed += 1
		progress += kept if landlord else kept - float(result["taxed"])
	assert_int(taxed).is_greater(0)
	assert_float(loop.state.set_progress).is_equal_approx(progress, 0.001)
	# The round's result says what the tax took, on its own line.
	var last: Dictionary = RoundSummaryScreen.last_round(loop.events())
	if float(results[-1]["taxed"]) > 0.0:
		assert_array(RoundSummaryScreen.debuff_lines(last)).has_size(1)


func test_overtime_banks_nothing_from_a_lost_round() -> void:
	var loop: RunLoop = DebuffScript.loop_with(23, "overtime")
	DebuffScript.play(loop)
	var results: Array[Dictionary] = _results(loop)
	var progress: float = 0.0
	var lost: int = 0
	for round_index: int in results.size():
		var result: Dictionary = results[round_index]
		var landlord: bool = result["landlord"] == RunLoop.PLAYER
		var void_now: bool = round_index >= 1 and bool(result["lost"])
		var kept: float = float(result["banked"]) if landlord else float(result["share"])
		if void_now:
			lost += 1
			if landlord:
				assert_float(kept).is_equal(0.0)
			else:
				assert_float(float(result["voided"])).is_equal(kept)
				kept = 0.0
		else:
			assert_float(float(result["voided"])).is_equal(0.0)
		progress += kept
	assert_int(lost).is_greater(0)
	assert_float(loop.state.set_progress).is_equal_approx(progress, 0.001)


## With Overfulfillment staked too, losing banks nothing and winning banks its multiple.
func test_overtime_and_overfulfillment_together() -> void:
	for won: bool in [false, true]:
		var loop: RunLoop = RunLoop.new(RunState.new(3), RunScript.bots())
		loop.campaigns.flags.staked = true
		loop.campaigns.flags.win_times = 2
		var winner: int = 0 if won else 1
		var ending: RoundContext = RoundContext.new(
			RunLoop.PLAYER, winner, RoundEvent.Finish.NORMAL
		)
		var overtime: OvertimeEffect = OvertimeEffect.new()
		overtime.holder_seat = RunLoop.PLAYER
		overtime.round_end(ending)
		loop.debuffs.ended(ending)
		var totals: PackedFloat64Array = [100.0, 40.0, 30.0]
		loop.campaigns.settle(totals, RunLoop.PLAYER, 0 if won else 1)
		loop.debuffs.settle(totals, RunLoop.PLAYER)
		assert_float(totals[RunLoop.PLAYER]).is_equal(200.0 if won else 0.0)


func test_big_character_poster_raises_denunciation_a_band_each_lost_round() -> void:
	_check_loss_meter("big_character_poster", RunMeters.DENUNCIATION, 29)


func test_hungry_winter_raises_famine_a_band_each_lost_round() -> void:
	_check_loss_meter("hungry_winter", RunMeters.FAMINE, 37)


## Checks Sets from seed_value on until one loses a round with the debuff in force.
func _check_loss_meter(debuff_id: String, meter: String, seed_value: int) -> void:
	for offset: int in 20:
		if _loss_meter_set(debuff_id, meter, seed_value + offset) > 0:
			return
	fail("No Set lost a round with %s in force" % debuff_id)


## Returns how many rounds in force the player's side lost.
func _loss_meter_set(debuff_id: String, meter: String, seed_value: int) -> int:
	var loop: RunLoop = DebuffScript.loop_with(seed_value, debuff_id)
	DebuffScript.play(loop)
	var band: int = RunDefaults.METERS.famine.low
	var row: String = RunMeters.DEBUFF_FAMINE
	if meter == RunMeters.DENUNCIATION:
		row = RunMeters.DEBUFF_DENUNCIATION
	assert_int(RunDefaults.METERS.source(row).amount).is_equal(band)
	var results: Array[Dictionary] = _results(loop)
	var rises: Dictionary[int, Array] = DebuffScript.per_round(loop, RunEvent.Type.METER_CHANGED)
	var lost: int = 0
	for round_index: int in results.size():
		var bands: int = 0
		for change: RunEvent in rises.get(round_index, []):
			if change.text == meter and change.value == band:
				bands += 1
		var expected: int = 1 if round_index >= 1 and bool(results[round_index]["lost"]) else 0
		assert_int(bands).override_failure_message("round %d" % round_index).is_equal(expected)
		lost += expected
	return lost

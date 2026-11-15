extends GdUnitTestSuite
## The debuffs of ADR 0023 through saves and bots: each random draw replays from a record
## to the same state, a save taken mid-round under a debuff that moved cards, left a
## Cadre out or shows a hand loads back identically, bots stay legal under every hand
## debuff, and a bot that reads hidden hands plays differently once it sees the player's.

const HAND_DEBUFFS: Array[String] = [
	"levy", "night_shift", "shared_kitchen", "glass_walls", "redistribution", "plot_seized"
]


func _setup(debuff_id: String) -> Callable:
	return func(state: RunState) -> void:
		if debuff_id == "confiscation":
			state.inventory.cadres.assign(["ration_coupon", "iron_rice_bowl", "red_banner"])
		if debuff_id == "plot_seized" or debuff_id == "shared_kitchen":
			for index: int in 3:
				state.inventory.plot.append(
					CardInstance.new(
						CardInstance.FIRST_PLOT_ID + index,
						Ranks.ACE,
						index,
						CardInstance.Origin.PLOT
					)
				)


func _resume(loop: RunLoop, debuff_id: String) -> RunLoop:
	var data: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
	assert_bool(RunRecord.is_valid(data)).is_true()
	return RunRecord.resume(
		data,
		RunScript.bots(),
		DebuffScript.hard_sets(),
		RunLoop.DEFAULT_PARAMS,
		DebuffScript.pool([debuff_id])
	)


## A save taken mid-round, a few plays into the round the debuff arrived in, resumes to
## the same state, hands, public view and log; and both play on to the same Set's end.
func test_a_save_mid_round_under_each_debuff_loads_back_identically() -> void:
	var ids: Array[String] = [
		"levy",
		"redistribution",
		"confiscation",
		"glass_walls",
		"slogan_of_the_week",
		"plot_seized",
	]
	for debuff_id: String in ids:
		var loop: RunLoop = DebuffScript.drawn(500, debuff_id, 3, _setup(debuff_id))
		assert_object(loop).override_failure_message(debuff_id).is_not_null()
		var arrives: int = loop.state.debuff_ladder.find(debuff_id)
		assert_bool(DebuffScript.play_into(loop, arrives, 3)).is_true()
		var resumed: RunLoop = _resume(loop, debuff_id)
		assert_object(resumed).override_failure_message(debuff_id).is_not_null()
		var here: String = DebuffScript.snapshot(loop)
		assert_str(DebuffScript.snapshot(resumed)).override_failure_message(debuff_id).is_equal(
			here
		)
		DebuffScript.play(loop)
		DebuffScript.play(resumed)
		assert_str(DebuffScript.snapshot(resumed)).override_failure_message(debuff_id).is_equal(
			DebuffScript.snapshot(loop)
		)
		if debuff_id == "slogan_of_the_week":
			assert_int(loop.state.slogan_type).is_not_equal(RunState.NO_SLOGAN)


## A schema 8 save has no Slogan: it gains none, and a save without the field is damaged.
func test_a_schema_8_save_gains_no_slogan() -> void:
	var record: RunRecord = RunRecord.new()
	record.mark(RunState.new(8))
	var data: Dictionary = record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("slogan_type")
	assert_bool(RunRecord.is_valid(data)).is_false()
	var migrated: Dictionary = RunRecord.migrate_from_8(data)
	assert_bool(RunRecord.is_valid(migrated)).is_true()
	var state: RunState = RunState.from_dict(migrated["checkpoint"])
	assert_int(state.slogan_type).is_equal(RunState.NO_SLOGAN)
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(9)


## Bots never choose an action the round refuses, under every debuff that changes hands.
func test_bots_stay_legal_under_every_hand_debuff() -> void:
	for debuff_id: String in HAND_DEBUFFS:
		for seed_value: int in [700, 800, 900]:
			var loop: RunLoop = DebuffScript.drawn(seed_value, debuff_id, 3, _setup(debuff_id))
			if loop == null:
				continue
			DebuffScript.play(loop)
			assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
			assert_int(loop.refused_bot_actions).override_failure_message(debuff_id).is_equal(0)


## Expert reasons over sampled deals of the unseen cards: with the player's hand shown, every
## sample deals the player exactly that hand.
func test_expert_samples_keep_a_shown_hand_as_it_is() -> void:
	var round_state: RoundState = _glass_round(4, 1)
	var view: SeatView = round_state.view_for(1)
	var shown: PackedByteArray = round_state.view_for(0).own_counts
	assert_bool(view.exposed[0] == shown).is_true()
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.EXPERT)
	var table: BotTable = BotTable.new(RuleSet.default_rules(), Ranks.identity_map())
	var scorer: CandidateScorer = CandidateScorer.new(view.own_counts, table, config.weights)
	var position: BotPosition = BotPosition.new(view, table, config, scorer)
	for sample: int in 5:
		var hands: Array[PackedByteArray] = ExpertSearch.deal_unseen(position, sample)
		assert_bool(hands[0] == shown).is_true()


## Hard bots play the same deals with and without the player's hand shown, and choose
## differently at some decisions.
func test_hard_bots_play_differently_when_they_see_your_hand() -> void:
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD)
	var table: BotTable = BotTable.new(RuleSet.default_rules(), Ranks.identity_map())
	var decisions: int = 0
	var different: int = 0
	for seed_value: int in 30:
		var round_state: RoundState = _glass_round(seed_value, seed_value % Seats.COUNT)
		while not round_state.is_over():
			var seat: int = round_state.seat_to_act()
			var legal: Array[Pattern] = round_state.legal_moves()
			var view: SeatView = round_state.view_for(seat)
			var seen: BotPlay = Bot.decide_play(view, legal, table, config, BotBudget.unlimited())
			if seat != RunLoop.PLAYER:
				decisions += 1
				var blind: SeatView = round_state.view_for(seat)
				blind.exposed.clear()
				var guessed: BotPlay = Bot.decide_play(
					blind, legal, table, config, BotBudget.unlimited()
				)
				if (
					seen.is_pass() != guessed.is_pass()
					or (not seen.is_pass() and not seen.pattern.equals(guessed.pattern))
				):
					different += 1
			var action: RoundAction = RoundAction.new(seat)
			if not seen.is_pass():
				action = round_state.action_for(seen.pattern)
			assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	assert_int(decisions).is_greater(100)
	assert_int(different).is_greater(0)


## A seeded round with Glass Walls held by the player.
func _glass_round(seed_value: int, landlord: int) -> RoundState:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(DebuffScript.definition("glass_walls"), RunLoop.PLAYER)
	return RoundState.new(SelfPlay.deal_from_seed(seed_value), landlord, SeatRules.new(stack))

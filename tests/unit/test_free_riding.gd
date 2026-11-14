extends GdUnitTestSuite
## P4.4: the teammate's effort falls from full at a fair share to its own cooperation at
## a full share, and a slacking bot still plays only legal moves.

const PARAMS: FreeRideParams = preload("res://data/run/free_ride.tres")


func test_effort_is_full_up_to_a_fair_share() -> void:
	for share: float in [0.0, 0.25, PARAMS.fair_share]:
		assert_float(FreeRiding.effort(share, 0.5, PARAMS)).is_equal(1.0)


func test_effort_falls_to_cooperation_at_a_full_share() -> void:
	for cooperation: float in BotConfig.TABLE.cooperation:
		assert_float(FreeRiding.effort(PARAMS.full_share, cooperation, PARAMS)).is_equal_approx(
			cooperation, 1e-6
		)


func test_effort_never_rises_as_the_share_grows() -> void:
	var last: float = 1.0
	for step: int in 101:
		var effort: float = FreeRiding.effort(step / 100.0, 0.5, PARAMS)
		assert_float(effort).is_less_equal(last)
		assert_float(effort).is_greater_equal(0.5)
		last = effort


func test_the_share_counts_what_reached_the_player() -> void:
	var state: RunState = RunState.new(3)
	assert_float(FreeRiding.share(state)).is_equal(0.0)
	state.landlord_seat = 1
	state.commons_pool = 300
	var events: Array[RunEvent] = []
	RoundBanking.split(state, 0, 20, RunScript.bots(), RunLoop.DEFAULT_PARAMS, events)
	assert_int(state.commons_paid).is_equal(300)
	assert_float(FreeRiding.share(state)).is_equal_approx(
		float(state.commons_received) / 300.0, 1e-9
	)
	assert_float(FreeRiding.share(state)).is_greater(0.5)


func test_a_bot_with_no_effort_passes_when_following_and_leads_its_weakest() -> void:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	var deal: DealResult = Dealer.deal(cards, RandomStream.new(11))
	var rules: SeatRules = SeatRules.new(ModifierStack.new())
	var round_state: RoundState = RoundState.new(deal, 0, rules)
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.HARD)
	config.effort = 0.0
	rules.refresh()
	var table: BotTable = BotTable.new(rules.rules_for(0), rules.map_for(0))
	var legal: Array[Pattern] = round_state.legal_moves()
	var lead: BotPlay = Bot.decide_play(
		round_state.view_for(0), legal, table, config, BotBudget.unlimited()
	)
	assert_int(lead.rationale).is_equal(BotRationale.Code.SLACKED)
	for move: Pattern in legal:
		assert_int(lead.pattern.key).is_less_equal(move.key)
	round_state.apply(round_state.action_for(lead.pattern))
	var follow: BotPlay = Bot.decide_play(
		round_state.view_for(1),
		round_state.legal_moves(),
		BotTable.new(rules.rules_for(1), rules.map_for(1)),
		config,
		BotBudget.unlimited()
	)
	assert_bool(follow.is_pass()).is_true()

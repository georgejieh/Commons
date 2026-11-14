extends GdUnitTestSuite
## P4.2 simulation: the same positions, decided by the same high-grudge bot with and
## without Resentment. Once the player owns a trick, a resented player's tricks are
## answered more often, by opponents and by their own teammate.

const DEALS: int = 200
const HIGH: int = Personality.Level.HIGH
const PARAMS: ResentmentParams = preload("res://data/run/resentment.tres")


## Seat 1 answers a trick the player owns. With the player as landlord seat 1 is an
## opponent; with seat 2 as landlord it is the player's teammate.
func _answers(resentment: int, landlord: int) -> int:
	var answered: int = 0
	for deal_index: int in DEALS:
		var cards: Array[CardInstance] = []
		for deck_id: int in Deck.generate():
			cards.append(CardInstance.from_deck_id(deck_id))
		var deal: DealResult = Dealer.deal(cards, RandomStream.new(4200 + deal_index))
		var rules: SeatRules = SeatRules.new(ModifierStack.new())
		var round_state: RoundState = RoundState.new(deal, landlord, rules)
		# Leads and answers are drawn at random, so the player owns tricks of every kind.
		var picks: RandomStream = RandomStream.new(9100 + deal_index)
		while round_state.seat_to_act() != 1 and not round_state.is_over():
			var legal: Array[Pattern] = round_state.legal_moves()
			if legal.is_empty():
				round_state.apply(RoundAction.new(round_state.seat_to_act()))
				continue
			var pick: Pattern = legal[picks.next_int(0, legal.size() - 1)]
			round_state.apply(round_state.action_for(pick))
		# Only a trick the player owns, with something seat 1 could beat it with.
		if round_state.is_over() or round_state.legal_moves().is_empty():
			continue
		if _trick_owner(round_state.view_for(1).public) != 0:
			continue
		var config: BotConfig = BotConfig.new(
			BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM, deal_index
		)
		config.grudge = BotConfig.TABLE.grudge[HIGH]
		config.memory = PackedFloat32Array([Resentment.grudge(resentment, PARAMS), 0.0, 0.0])
		rules.refresh()
		var play: BotPlay = Bot.decide_play(
			round_state.view_for(1),
			round_state.legal_moves(),
			BotTable.new(rules.rules_for(1), rules.map_for(1)),
			config,
			BotBudget.unlimited()
		)
		answered += 0 if play.is_pass() else 1
	return answered


func test_opponents_answer_a_resented_player_more() -> void:
	var calm: int = _answers(0, 0)
	var resented: int = _answers(PARAMS.max, 0)
	print("opponent answers: %d calm, %d resented" % [calm, resented])
	assert_int(resented).is_greater(calm)


func test_a_teammate_covers_less_for_a_resented_player() -> void:
	var calm: int = _answers(0, 2)
	var resented: int = _answers(PARAMS.max, 2)
	print("teammate answers: %d calm, %d resented" % [calm, resented])
	assert_int(resented).is_greater(calm)


func _trick_owner(public: PublicView) -> int:
	if public.current_play == null:
		return Seats.NONE
	for index: int in range(public.history.size() - 1, -1, -1):
		if public.history[index].pattern.type != Pattern.Type.PASS:
			return public.history[index].seat
	return Seats.NONE

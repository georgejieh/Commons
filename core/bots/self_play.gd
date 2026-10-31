class_name SelfPlay
extends RefCounted
## Plays bots against each other on the real round rules. An illegal action is counted
## and replaced, so one bad decision can't end a long run. Pass a clock to time decisions.

const MAX_ACTIONS: int = 1000


## configs has one entry per seat. table's modifiers stay as they are between rounds.
static func play_round(
	deal: DealResult,
	landlord: int,
	configs: Array[BotConfig],
	table: SeatRules,
	clock: Callable = Callable()
) -> SelfPlayResult:
	var round_state: RoundState = RoundState.new(deal, landlord, table)
	var result: SelfPlayResult = SelfPlayResult.new()
	result.landlord = landlord
	result.cards_played.resize(Seats.COUNT)
	for _action: int in MAX_ACTIONS:
		if round_state.is_over():
			break
		_take_turn(round_state, configs, table, clock, result)
	result.winner = round_state.winner()
	return result


## Plays a deal twice with the sides swapped: first as landlord in seat 0 against two of
## second, then the reverse. Returns how many of the two games first won (ADR 0010).
static func play_duplicate(
	deal: DealResult, first: BotConfig, second: BotConfig, table: SeatRules
) -> int:
	var as_landlord: Array[BotConfig] = [first, second, second]
	var as_peasants: Array[BotConfig] = [second, first, first]
	var wins: int = 0
	if play_round(deal, 0, as_landlord, table).landlord_won():
		wins += 1
	if not play_round(deal, 0, as_peasants, table).landlord_won():
		wins += 1
	return wins


## Runs bidding over a deal. A seat's first hand is its deal, because the kitty comes later.
static func bid_round(
	deal: DealResult, configs: Array[BotConfig], table: BotTable, first_seat: int
) -> Bidding:
	var bidding: Bidding = Bidding.new(first_seat)
	while bidding.phase() != Bidding.Phase.DONE:
		var seat: int = bidding.seat_to_act()
		var is_grab: bool = bidding.phase() == Bidding.Phase.GRABBING
		var claim: bool = Bot.decide_bid(
			deal.hands[seat].counts(),
			is_grab,
			bidding.is_last_to_act(),
			table,
			configs[seat],
			BotBudget.unlimited()
		)
		bidding.act(seat, claim)
	return bidding


## Deals one seeded hand from a fresh deck.
static func deal_from_seed(deal_seed: int) -> DealResult:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	return Dealer.deal(cards, RandomStream.new(deal_seed))


static func _take_turn(
	round_state: RoundState,
	configs: Array[BotConfig],
	table: SeatRules,
	clock: Callable,
	result: SelfPlayResult
) -> void:
	var seat: int = round_state.seat_to_act()
	var legal: Array[Pattern] = round_state.legal_moves()
	var seat_table: BotTable = BotTable.new(table.rules_for(seat), table.map_for(seat))
	var started: int = clock.call() if clock.is_valid() else 0
	var play: BotPlay = Bot.decide_play(
		round_state.view_for(seat), legal, seat_table, configs[seat], BotBudget.unlimited()
	)
	if clock.is_valid():
		result.decision_usec.append(clock.call() - started)
	result.decisions += 1
	var reason: RoundState.Reason = round_state.apply(_action_for(round_state, play))
	if reason != RoundState.Reason.OK:
		result.illegal_actions += 1
		var fallback: Pattern = legal[0] if not legal.is_empty() else Pattern.pass_play()
		round_state.apply(_action_for(round_state, BotPlay.new(fallback)))
		play = BotPlay.new(fallback)
	result.cards_played[seat] += play.pattern.card_count


static func _action_for(round_state: RoundState, play: BotPlay) -> RoundAction:
	if play.is_pass():
		return RoundAction.new(round_state.seat_to_act())
	return round_state.action_for(play.pattern)

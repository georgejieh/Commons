extends GdUnitTestSuite
## Card-count announcements fire exactly once per threshold crossing (P3B.8): a play
## that leaves a seat at 2 or 1 cards announces it once, the same count never announces
## twice in a round, and no other play announces anything.

const SEED: int = 3808
const GAMES: int = 1000
const MAX_ACTIONS: int = 162

var _rules: RuleSet = RuleSet.default_rules()
var _map: PackedByteArray = Ranks.identity_map()


func test_every_crossing_announces_once_over_random_games() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var problems: PackedStringArray = []
	var crossings: int = 0
	for game: int in GAMES:
		var cards: Array[CardInstance] = []
		for deck_id: int in Deck.generate():
			cards.append(CardInstance.from_deck_id(deck_id))
		var round_state: RoundState = RoundState.new(
			Dealer.deal(cards, stream), game % Seats.COUNT, SeatRules.uniform(_rules, _map)
		)
		crossings += _play_and_check(round_state, stream, problems)
	assert_array(problems).is_empty()
	assert_int(crossings).is_greater(GAMES)


## Plays one random game, checking each action's announcements. Returns the crossings.
func _play_and_check(
	round_state: RoundState, stream: RandomStream, problems: PackedStringArray
) -> int:
	var announced: Dictionary[String, bool] = {}
	var crossings: int = 0
	var actions: int = 0
	while not round_state.is_over() and actions < MAX_ACTIONS:
		actions += 1
		var seat: int = round_state.seat_to_act()
		var before: int = round_state.remaining()[seat]
		var event_count: int = round_state.events().size()
		round_state.apply(_random_action(round_state, stream))
		var after: int = round_state.remaining()[seat]
		var expected: bool = after != before and _rules.announces_at(after)
		var calls: Array[int] = _announcements(round_state, event_count)
		if expected:
			crossings += 1
			var key: String = "%d:%d" % [seat, after]
			if calls != [after] or announced.has(key):
				problems.append("seat %d at %d announced %s" % [seat, after, calls])
			announced[key] = true
		elif not calls.is_empty():
			problems.append("seat %d at %d announced %s unasked" % [seat, after, calls])
	return crossings


func _random_action(round_state: RoundState, stream: RandomStream) -> RoundAction:
	var moves: Array[Pattern] = round_state.legal_moves()
	var pick: int = stream.next_int(0, moves.size())
	if pick == moves.size() and round_state.current_play() == null:
		pick = 0
	if pick < moves.size():
		return round_state.action_for(moves[pick])
	return RoundAction.new(round_state.seat_to_act())


func _announcements(round_state: RoundState, from: int) -> Array[int]:
	var values: Array[int] = []
	for event: RoundEvent in round_state.events().slice(from):
		if event.type == RoundEvent.Type.ANNOUNCED:
			values.append(event.value)
	return values

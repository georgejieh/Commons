extends GdUnitTestSuite
## Scripted games reproduce exact event logs. The policy plays its first legal move, or
## passes every third chance, so each seed gives one fixed game.
## Set UPDATE_GOLDEN=1 to rewrite the golden file after an intended change.

const GOLDEN_PATH: String = "res://tests/golden/round_games.golden"
const SEEDS: Array[int] = [101, 202, 303, 404, 505]
const PASS_EVERY: int = 3


func _game_log(seed_value: int) -> PackedStringArray:
	var streams: RandomStreams = RandomStreams.new(seed_value)
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	var deal: DealResult = Dealer.deal(cards, streams.stream(RandomStreams.DEAL))
	var landlord: int = seed_value % Seats.COUNT
	var round_state: RoundState = RoundState.new(
		deal, landlord, RuleSet.default_rules(), Ranks.identity_map()
	)
	var turn: int = 0
	while not round_state.is_over():
		turn += 1
		var seat: int = round_state.seat_to_act()
		var moves: Array[Pattern] = round_state.legal_moves()
		var may_pass: bool = round_state.current_play() != null
		if moves.is_empty() or (may_pass and turn % PASS_EVERY == 0):
			round_state.apply(RoundAction.new(seat))
		else:
			var chosen: Array[CardInstance] = CardSelection.pick(
				round_state.hand_for_selection(), moves[0]
			)
			round_state.apply(RoundAction.from_cards(seat, chosen))

	var lines: PackedStringArray = ["game %d" % seed_value]
	for event: RoundEvent in round_state.events():
		lines.append(event.describe())
	return lines


func _all_games() -> String:
	var lines: PackedStringArray = []
	for seed_value: int in SEEDS:
		lines.append_array(_game_log(seed_value))
	return "\n".join(lines) + "\n"


func test_games_are_repeatable() -> void:
	assert_str(_all_games()).is_equal(_all_games())


func test_games_match_the_golden_file() -> void:
	var text: String = _all_games()
	if OS.get_environment("UPDATE_GOLDEN") == "1":
		var file: FileAccess = FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	var golden: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	assert_str(golden.replace("\r", "")).is_equal(text)

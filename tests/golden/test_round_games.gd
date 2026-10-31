extends GdUnitTestSuite
## Games reproduce exact event logs. Seeded games play the largest legal move, or pass
## every third chance. Authored games cover compound plays and every finish.
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
		deal, landlord, SeatRules.uniform(RuleSet.default_rules(), Ranks.identity_map())
	)
	var turn: int = 0
	while not round_state.is_over():
		turn += 1
		var seat: int = round_state.seat_to_act()
		var moves: Array[Pattern] = round_state.legal_moves()
		var may_pass: bool = round_state.current_play() != null
		var action: RoundAction = RoundAction.new(seat)
		if not moves.is_empty() and not (may_pass and turn % PASS_EVERY == 0):
			action = round_state.action_for(_largest(moves))
		assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)

	var lines: PackedStringArray = ["game %d" % seed_value]
	for event: RoundEvent in round_state.events():
		lines.append(event.describe())
	return lines


func _largest(moves: Array[Pattern]) -> Pattern:
	var best: Pattern = moves[0]
	for move: Pattern in moves:
		if move.card_count > best.card_count:
			best = move
	return best


## Each play is cards, or "-" for a pass.
func _authored_log(name: String, hands: Array[String], plays: Array[String]) -> PackedStringArray:
	var rules: RuleSet = RuleSet.default_rules()
	var deal: DealResult = RoundScript.stacked_deal(hands, "")
	var round_state: RoundState = RoundState.new(
		deal, 0, SeatRules.uniform(rules, Ranks.identity_map())
	)
	for play: String in plays:
		var action: RoundAction = RoundAction.new(round_state.seat_to_act())
		if play != "-":
			action = RoundScript.play(round_state, play)
		assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	assert_bool(round_state.is_over()).is_true()
	var lines: PackedStringArray = ["game " + name]
	for event: RoundEvent in round_state.events():
		lines.append(event.describe())
	return lines


func _all_games() -> String:
	var lines: PackedStringArray = []
	for seed_value: int in SEEDS:
		lines.append_array(_game_log(seed_value))
	lines.append_array(
		_authored_log(
			"compound",
			["33344456sb", "7778889T2222", "JJJJQQKK"],
			["33344456", "7778889T", "-", "sb"]
		)
	)
	lines.append_array(
		_authored_log(
			"bombs",
			["334455KK", "66778899", "TTTTJJJA"],
			["334455", "667788", "TTTT", "-", "-", "JJJA"]
		)
	)
	lines.append_array(_authored_log("spring", ["345678", "9", "T"], ["34567", "-", "-", "8"]))
	lines.append_array(_authored_log("anti spring", ["3K", "4", "5"], ["3", "4"]))
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

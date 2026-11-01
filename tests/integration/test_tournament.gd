extends GdUnitTestSuite
## The tournament harness: its rows, its CSV and its game log.

const GAMES: int = 6


func _run() -> TournamentRun:
	var run: TournamentRun = TournamentRun.new("medium", "easy", 0, true)
	run.play_duplicate(GAMES)
	return run


func test_duplicate_games_split_evenly_by_side() -> void:
	var lines: PackedStringArray = _run().tally.csv().strip_edges().split("\n")
	assert_str(lines[0]).is_equal(TournamentTally.HEADER)
	assert_str(lines[1]).starts_with("duplicate,medium,landlord,0,3,")
	assert_str("\n".join(lines)).contains("duplicate,easy,landlord,0,3,")
	assert_str("\n".join(lines)).contains("duplicate,medium,peasant,1,3,")


func test_win_rates_of_the_two_configs_sum_to_one() -> void:
	var tally: TournamentTally = _run().tally
	var first: float = tally.win_rate(TournamentRun.DUPLICATE, "medium")
	var second: float = tally.win_rate(TournamentRun.DUPLICATE, "easy")
	assert_float(first + second).is_equal_approx(1.0, 0.0001)


func test_a_tournament_counts_no_illegal_action() -> void:
	assert_int(_run().tally.illegal_actions).is_equal(0)


func test_bidding_mode_plays_a_game_for_every_claimed_deal() -> void:
	var run: TournamentRun = TournamentRun.new("medium", "easy")
	run.play_bidding(GAMES)
	assert_str(run.tally.csv()).contains("bidding,")


func test_the_log_replays_the_cards_each_seat_held() -> void:
	var record: Dictionary = JSON.parse_string(_run().log_lines[0])
	var cards: int = 0
	for hand: String in record["hands"]:
		cards += hand.length()
	assert_int(cards + String(record["kitty"]).length()).is_equal(54)
	var played: int = 0
	for play: Array in record["plays"]:
		if int(play[0]) == int(record["winner"]):
			played += String(play[1]).length()
	var winner_hand: String = record["hands"][int(record["winner"])]
	var extra: int = 3 if int(record["winner"]) == int(record["landlord"]) else 0
	assert_int(played).is_equal(winner_hand.length() + extra)

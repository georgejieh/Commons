extends GdUnitTestSuite
## Each trigger in ADR 0012, on events built by hand.

const FAMILIES: Array[String] = ["player", "wang", "li"]
const PLAYER: int = 0
const BOMB: String = "8888"
const PAIR: String = "99"


func test_a_bomb_on_an_opponent_counts_as_bombed_only() -> void:
	# Player is a peasant; seat 1 is the landlord.
	var summary: SetSummary = _fold(1, [_play(1, "33"), _play(PLAYER, BOMB)])
	assert_int(summary.count("wang", SetSummary.Kind.BOMBED)).is_equal(1)
	assert_int(summary.count("wang", SetSummary.Kind.BETRAYED)).is_equal(0)


func test_a_bomb_on_the_teammate_counts_as_bombed_and_betrayed() -> void:
	var summary: SetSummary = _fold(1, [_play(2, "33"), _play(PLAYER, BOMB)])
	assert_int(summary.count("li", SetSummary.Kind.BOMBED)).is_equal(1)
	assert_int(summary.count("li", SetSummary.Kind.BETRAYED)).is_equal(1)


func test_beating_the_teammate_counts_as_betrayed() -> void:
	var summary: SetSummary = _fold(1, [_play(2, "55"), _play(PLAYER, PAIR)])
	assert_int(summary.count("li", SetSummary.Kind.BETRAYED)).is_equal(1)
	assert_int(summary.count("li", SetSummary.Kind.BOMBED)).is_equal(0)


func test_the_landlord_beating_a_peasant_is_not_a_betrayal() -> void:
	var summary: SetSummary = _fold(PLAYER, [_play(1, "55"), _play(PLAYER, PAIR)])
	assert_int(summary.count("wang", SetSummary.Kind.BETRAYED)).is_equal(0)


func test_a_new_trick_is_not_an_answer() -> void:
	var events: Array[RunEvent] = [
		_play(2, "55"), RunEvent.wrap(RoundEvent.new(RoundEvent.Type.TRICK_WON, 2)), _play(0, BOMB)
	]
	var summary: SetSummary = _fold(1, events)
	assert_int(summary.count("li", SetSummary.Kind.BOMBED)).is_equal(0)


func test_a_share_paid_after_the_player_banked_counts_as_fed() -> void:
	var events: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.ROUND_SCORED, PLAYER, 0, 50.0),
		RunEvent.new(RunEvent.Type.SHARE_PAID, 2, 30),
		RunEvent.new(RunEvent.Type.SHARE_PAID, PLAYER, 20),
	]
	var summary: SetSummary = _fold(1, events)
	assert_int(summary.count("li", SetSummary.Kind.FED)).is_equal(1)
	assert_int(summary.count("player", SetSummary.Kind.FED)).is_equal(0)


func test_no_feeding_when_the_player_banked_nothing_or_is_landlord() -> void:
	var nothing: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.ROUND_SCORED, PLAYER, 0, 0.0),
		RunEvent.new(RunEvent.Type.SHARE_PAID, 2, 30),
	]
	assert_int(_fold(1, nothing).count("li", SetSummary.Kind.FED)).is_equal(0)
	var landlord: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.ROUND_SCORED, PLAYER, 0, 50.0),
		RunEvent.new(RunEvent.Type.SHARE_PAID, 2, 30),
	]
	assert_int(_fold(PLAYER, landlord).count("li", SetSummary.Kind.FED)).is_equal(0)


func _fold(landlord: int, events: Array[RunEvent]) -> SetSummary:
	var round_events: Array[RunEvent] = [
		RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, landlord))
	]
	round_events.append_array(events)
	var summary: SetSummary = SetSummary.new(0)
	SummaryFold.fold_round(summary, round_events, PLAYER, FAMILIES)
	return summary


func _play(seat: int, text: String) -> RunEvent:
	var event: RoundEvent = RoundEvent.new(RoundEvent.Type.PLAYED, seat)
	var map: PackedByteArray = Ranks.identity_map()
	event.pattern = Classifier.classify(RankText.counts(text), RuleSet.default_rules(), map).pattern
	return RunEvent.wrap(event)

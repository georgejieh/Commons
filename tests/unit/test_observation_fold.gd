extends GdUnitTestSuite
## What the dossier records about villagers, on events built by hand (P3B.8).

const FAMILIES: Array[String] = ["player", "wang", "zhao"]
const PLAYER: int = 0


func test_bids_and_calls_count_for_villagers_only() -> void:
	var events: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.BID, PLAYER, 1),
		RunEvent.new(RunEvent.Type.BID, 1, 0),
		RunEvent.new(RunEvent.Type.BID, 2, 1),
	]
	var seen: Observations = _fold(2, events)
	assert_int(seen.count("wang", Observations.Kind.BIDS)).is_equal(1)
	assert_int(seen.count("wang", Observations.Kind.CALLS)).is_equal(0)
	assert_int(seen.count("zhao", Observations.Kind.CALLS)).is_equal(1)
	assert_bool(seen.has_family("player")).is_false()


func test_a_villager_landlord_round_counts_once() -> void:
	var seen: Observations = _fold(1, [])
	assert_int(seen.count("wang", Observations.Kind.LANDLORD_ROUNDS)).is_equal(1)
	assert_int(seen.count("zhao", Observations.Kind.LANDLORD_ROUNDS)).is_equal(0)


func test_bombs_and_passes_count() -> void:
	var events: Array[RunEvent] = [_play(PLAYER, "33"), _play(1, "8888"), _pass(2), _pass(1)]
	var seen: Observations = _fold(PLAYER, events)
	assert_int(seen.count("wang", Observations.Kind.BOMBS)).is_equal(1)
	assert_int(seen.count("wang", Observations.Kind.PASSES)).is_equal(1)
	assert_int(seen.count("zhao", Observations.Kind.PASSES)).is_equal(1)


func test_a_peasant_beating_their_teammate_counts() -> void:
	# Seat 2 is landlord, so the player and Wang are teammates.
	var seen: Observations = _fold(2, [_play(PLAYER, "55"), _play(1, "99")])
	assert_int(seen.count("wang", Observations.Kind.BEAT_TEAMMATE)).is_equal(1)


func test_beating_the_landlord_or_leading_is_not_beating_a_teammate() -> void:
	var events: Array[RunEvent] = [
		_play(2, "55"), _play(1, "99"), _trick_won(1), _play(1, "4"), _play(2, "6")
	]
	var seen: Observations = _fold(2, events)
	assert_int(seen.count("wang", Observations.Kind.BEAT_TEAMMATE)).is_equal(0)
	assert_int(seen.count("zhao", Observations.Kind.BEAT_TEAMMATE)).is_equal(0)


func test_going_out_first_counts_for_the_winner() -> void:
	var ended: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 2))
	var seen: Observations = _fold(PLAYER, [ended])
	assert_int(seen.count("zhao", Observations.Kind.WENT_OUT)).is_equal(1)


func test_observations_round_trip_and_accumulate() -> void:
	var seen: Observations = _fold(1, [_play(1, "8888")])
	ObservationFold.fold_round(seen, _round(1, [_play(1, "9999")]), PLAYER, FAMILIES)
	assert_int(seen.count("wang", Observations.Kind.BOMBS)).is_equal(2)
	var copy: Observations = Observations.from_dict(
		JSON.parse_string(JSON.stringify(seen.to_dict()))
	)
	assert_dict(copy.to_dict()).is_equal(seen.to_dict())


func _fold(landlord: int, events: Array[RunEvent]) -> Observations:
	var seen: Observations = Observations.new()
	ObservationFold.fold_round(seen, _round(landlord, events), PLAYER, FAMILIES)
	return seen


func _round(landlord: int, events: Array[RunEvent]) -> Array[RunEvent]:
	var round_events: Array[RunEvent] = []
	var bids: Array[RunEvent] = []
	for event: RunEvent in events:
		if event.type == RunEvent.Type.BID:
			bids.append(event)
	round_events.append_array(bids)
	round_events.append(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, landlord)))
	for event: RunEvent in events:
		if event.type != RunEvent.Type.BID:
			round_events.append(event)
	return round_events


func _play(seat: int, text: String) -> RunEvent:
	var event: RoundEvent = RoundEvent.new(RoundEvent.Type.PLAYED, seat)
	var map: PackedByteArray = Ranks.identity_map()
	event.pattern = Classifier.classify(RankText.counts(text), RuleSet.default_rules(), map).pattern
	return RunEvent.wrap(event)


func _pass(seat: int) -> RunEvent:
	return RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PASSED, seat))


func _trick_won(seat: int) -> RunEvent:
	return RunEvent.wrap(RoundEvent.new(RoundEvent.Type.TRICK_WON, seat))

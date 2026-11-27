extends GdUnitTestSuite
## Every domain event type maps to an audio event name (P3B.10).


func test_every_run_event_type_has_a_name() -> void:
	for type: int in RunEvent.Type.values():
		(
			assert_bool(AudioEvents.RUN_NAMES.has(type))
			. override_failure_message(RunEvent.Type.keys()[type])
			. is_true()
		)


func test_every_round_event_type_has_a_name() -> void:
	for type: int in RoundEvent.Type.values():
		(
			assert_str(AudioEvents.ROUND_NAMES.get(type, ""))
			. override_failure_message(RoundEvent.Type.keys()[type])
			. is_not_empty()
		)


func test_round_events_take_their_round_name_and_bombs_their_own() -> void:
	var pass_event: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PASSED, 1))
	assert_str(AudioEvents.name_for(pass_event)).is_equal("passed")
	var bomb: Pattern = (
		Classifier
		. classify(RankText.counts("9999"), RuleSet.default_rules(), Ranks.identity_map())
		. pattern
	)
	var bomb_event: RunEvent = RunEvent.wrap(
		RoundEvent.new(RoundEvent.Type.PLAYED, 1, [24, 25, 26, 27], bomb)
	)
	assert_str(AudioEvents.name_for(bomb_event)).is_equal(AudioEvents.BOMB_NAME)


func test_every_name_is_unique() -> void:
	var seen: Dictionary[String, bool] = {}
	for name: String in AudioEvents.RUN_NAMES.values() + AudioEvents.ROUND_NAMES.values():
		if name.is_empty():
			continue
		assert_bool(seen.has(name)).override_failure_message(name).is_false()
		seen[name] = true


func test_rockets_and_bombs_have_their_own_names() -> void:
	var rocket: Pattern = (
		Classifier
		. classify(RankText.counts("sb"), RuleSet.default_rules(), Ranks.identity_map())
		. pattern
	)
	var event: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.PLAYED, 1, [52, 53], rocket))
	assert_str(AudioEvents.name_for(event)).is_equal(AudioEvents.ROCKET_NAME)


func test_a_round_is_won_or_lost_from_the_players_side() -> void:
	var landlord_out: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 2))
	var peasant_out: RunEvent = RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 1))
	# You hold the seat: only your own finish wins.
	assert_str(AudioEvents.name_for(peasant_out, 0)).is_equal(AudioEvents.ROUND_LOST)
	# A villager holds seat 2: your teammate's finish is your win.
	assert_str(AudioEvents.name_for(peasant_out, 2)).is_equal(AudioEvents.ROUND_WON)
	assert_str(AudioEvents.name_for(landlord_out, 2)).is_equal(AudioEvents.ROUND_LOST)
	# Without a landlord the plain name stands.
	assert_str(AudioEvents.name_for(landlord_out)).is_equal("round_ended")


func test_a_meter_rises_past_a_mark_once() -> void:
	var marks: Array[int] = [25, 50]
	assert_bool(AudioEvents.meter_rose(20, 30, marks)).is_true()
	assert_bool(AudioEvents.meter_rose(25, 40, marks)).is_false()
	assert_bool(AudioEvents.meter_rose(60, 40, marks)).is_false()
	assert_bool(AudioEvents.meter_rose(49, 50, marks)).is_true()

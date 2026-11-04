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

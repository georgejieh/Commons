extends GdUnitTestSuite
## Banking a round keeps the Commons pool in range.


func test_two_saturated_peasant_totals_do_not_wrap_the_pool() -> void:
	var state: RunState = RunState.new(1)
	state.landlord_seat = 1
	var totals: PackedFloat64Array = PackedFloat64Array([1e19, 5.0, 1e19])
	var events: Array[RunEvent] = []
	RoundBanking.bank(state, totals, 0, events)
	assert_int(state.commons_pool).is_equal(Banking.MAX_POOL)
	RoundBanking.split(state, 0, 10, RunScript.bots(), RunLoop.DEFAULT_PARAMS, events)
	for event: RunEvent in events:
		if event.type == RunEvent.Type.SHARE_PAID:
			assert_int(event.value).is_greater_equal(0)
	assert_int(state.commons_pool).is_equal(0)


func test_the_landlord_banks_only_their_own_total() -> void:
	var state: RunState = RunState.new(1)
	state.landlord_seat = 0
	var events: Array[RunEvent] = []
	RoundBanking.bank(state, PackedFloat64Array([120.0, 30.5, 40.9]), 0, events)
	assert_float(state.set_progress).is_equal(120.0)
	assert_int(state.commons_pool).is_equal(70)

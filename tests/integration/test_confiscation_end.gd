extends GdUnitTestSuite
## A Cadre a Confiscation leaves out of a round is held again once that round is over
## (ADR 0023).


func _held(state: RunState) -> void:
	state.inventory.cadres.assign(["ration_coupon"])


## The round it was left out of is over when the Quota ends, so the Cadre is held again for
## the Quota's end: Ration Coupon starts the next Quota with its counts at none.
func test_a_cadre_confiscated_in_the_last_round_still_meets_the_quotas_end() -> void:
	var loop: RunLoop = DebuffScript.loop_with(73, "confiscation", 1, _held)
	var counted: Array[int] = []
	DebuffScript.play(
		loop,
		func(at: RunLoop) -> bool:
			if at.state.round_index == 1 and counted.is_empty():
				counted.append(at.state.cadre_memos.entry("ration_coupon").value("passed"))
			return false
	)
	# The seed has the player pass in the round before the Confiscation, so there is a
	# count to clear.
	assert_int(counted[0]).is_greater(0)
	assert_array(DebuffScript.all_of(loop, RunEvent.Type.SET_ENDED)).is_not_empty()
	assert_array(loop.debuffs.confiscated_ids()).is_empty()
	assert_int(loop.state.cadre_memos.entry("ration_coupon").value("passed")).is_equal(0)
	assert_int(loop.state.cadre_memos.entry("ration_coupon").value("earned")).is_equal(0)

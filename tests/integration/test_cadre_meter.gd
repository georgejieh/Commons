extends GdUnitTestSuite
## A count on a Cadre's card reads at a glance (P5.2a). The owner saw Ration Coupon's
## "2/3" over a green band that never moved, and took it for a stuck meter. The band now
## fills with a count of so many out of so many and empties when the count starts again;
## a count that is not out of anything, a number, a factor or a rank, has no band.

const SEED: int = 5104
const CAP: int = 3


func test_a_count_out_of_a_whole_fills_the_band_that_share() -> void:
	assert_float(CadreBadge.meter("0/3")).is_equal(0.0)
	assert_float(CadreBadge.meter("1/3")).is_equal_approx(1.0 / 3.0, 0.0001)
	assert_float(CadreBadge.meter("2/3")).is_equal_approx(2.0 / 3.0, 0.0001)
	assert_float(CadreBadge.meter("3/3")).is_equal(1.0)
	assert_float(CadreBadge.meter("5/3")).is_equal(1.0)


func test_any_other_count_has_no_band() -> void:
	for count: String in ["", "+2", "7s", "12", "×1.5", "1/0", "a/b", "1/2/3"]:
		assert_float(CadreBadge.meter(count)).override_failure_message(count).is_less(0.0)


## Drawn at every step without fault, and the badge says how full it stands.
func test_the_badge_draws_each_step() -> void:
	var badge: CadreBadge = auto_free(CadreBadge.new())
	add_child(badge)
	badge.size = Vector2(110, 150)
	for earned: int in CAP + 1:
		badge.show_count("%d/%d" % [earned, CAP])
		await await_idle_frame()
		assert_float(badge.fill_share()).is_equal_approx(float(earned) / CAP, 0.0001)
	badge.show_count("+2")
	await await_idle_frame()
	assert_float(badge.fill_share()).is_less(0.0)


## Over a real Quota the count Ration Coupon shows rises a step at a time as passes pay,
## and starts again at the Quota's end, so the band fills and then empties.
func test_ration_coupons_band_fills_through_a_quota_and_empties_at_its_end() -> void:
	var state: RunState = RunState.new(SEED)
	state.inventory.cadres.assign(["ration_coupon"])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	var script: RunScript = RunScript.new()
	var fills: Array[float] = [_fill(loop)]
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER and script.act(loop):
		var now: float = _fill(loop)
		if now != fills[-1]:
			fills.append(now)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	# It rose one coupon at a time, and was emptied by the Quota's end.
	assert_int(fills.size()).is_greater(2)
	assert_float(fills[-1]).is_equal(0.0)
	for index: int in range(1, fills.size() - 1):
		assert_float(fills[index] - fills[index - 1]).is_equal_approx(1.0 / CAP, 0.0001)


func _fill(loop: RunLoop) -> float:
	var memo: CadreMemo = loop.state.cadre_memos.peek("ration_coupon")
	var earned: int = memo.value(RationCouponEffect.EARNED) if memo != null else 0
	return CadreBadge.meter("%d/%d" % [earned, CAP])

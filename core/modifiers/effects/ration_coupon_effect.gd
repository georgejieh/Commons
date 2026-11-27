class_name RationCouponEffect
extends ModifierEffect
## Every passes-th pass the player makes in a Quota earns coupons, up to cap a Quota. A
## pass the rules force counts like any other. The count starts again at each Quota's
## end.

## Parameter key: how many passes make a payout.
const PASSES: String = "passes"
## Parameter key: the coupons each payout earns.
const COUPONS: String = "coupons"
## Parameter key: the most coupons it earns in a Quota.
const CAP: String = "cap"
## Memo key: the passes counted this Quota.
const PASSED: String = "passed"
## Memo key: the coupons earned this Quota.
const EARNED: String = "earned"


## Needs the passes per payout, the coupons and the cap.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([PASSES, COUPONS, CAP])


## Counts the player's passes and pays at every passes-th, up to the cap.
func turn_taken(context: TurnContext) -> void:
	if not context.is_pass() or context.seat != holder_seat or context.seat != context.player:
		return
	var passed: int = memo.add(PASSED, 1)
	var earned: int = memo.value(EARNED)
	if passed % parameters[PASSES] != 0 or earned >= parameters[CAP]:
		return
	var paid: int = mini(parameters[COUPONS], parameters[CAP] - earned)
	memo.put(EARNED, earned + paid)
	context.coupons += paid
	memo.fire(paid)


## Starts the count and the earnings again at the Quota's end.
func set_end(_context: SetContext) -> void:
	memo.put(PASSED, 0)
	memo.put(EARNED, 0)


## What it has earned and the passes counted, and earned over cap as its badge.
func state_values() -> Dictionary[String, Variant]:
	var earned: int = memo.value(EARNED)
	return {
		"earned": earned,
		"passed": memo.value(PASSED),
		"count": "%d/%d" % [earned, parameters[CAP]],
	}

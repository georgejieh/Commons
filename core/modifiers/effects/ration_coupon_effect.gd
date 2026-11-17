class_name RationCouponEffect
extends ModifierEffect
## Every passes-th pass the player makes in a Quota earns coupons, up to cap a Quota. A
## pass the rules force counts like any other. The count starts again at each Quota's
## end.

const PASSES: String = "passes"
const COUPONS: String = "coupons"
const CAP: String = "cap"
const PASSED: String = "passed"
const EARNED: String = "earned"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([PASSES, COUPONS, CAP])


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


func set_end(_context: SetContext) -> void:
	memo.put(PASSED, 0)
	memo.put(EARNED, 0)


func state_values() -> Dictionary[String, Variant]:
	var earned: int = memo.value(EARNED)
	return {
		"earned": earned,
		"passed": memo.value(PASSED),
		"count": "%d/%d" % [earned, parameters[CAP]],
	}

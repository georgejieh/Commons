class_name GrainSpeculatorEffect
extends ModifierEffect
## Each step a met Quota beats its target by pays more coupons and adds more Resentment,
## on top of what every step pays and adds (ADR 0032). The norm's own rise is left as it
## is.

const COUPONS: String = "coupons"
const RESENTMENT: String = "resentment"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS, RESENTMENT])


func set_end(context: SetContext) -> void:
	if context.over_steps <= 0:
		return
	var paid: int = context.over_steps * parameters[COUPONS]
	context.add_coupons += paid
	context.add_resentment += context.over_steps * parameters[RESENTMENT]
	memo.fire(paid)

class_name BookkeeperEffect
extends ModifierEffect
## At a Quota's end, before it pays, the player earns coupons for every per coupons they
## hold, up to cap.

const PER: String = "per"
const COUPONS: String = "coupons"
const CAP: String = "cap"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([PER, COUPONS, CAP])


func set_end(context: SetContext) -> void:
	@warning_ignore("integer_division")
	var lots: int = context.coupons / parameters[PER]
	var paid: int = mini(lots * parameters[COUPONS], parameters[CAP])
	if paid > 0:
		context.add_coupons += paid
		memo.fire(paid)

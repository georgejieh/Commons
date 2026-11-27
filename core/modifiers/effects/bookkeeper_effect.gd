class_name BookkeeperEffect
extends ModifierEffect
## At a Quota's end, before it pays, the player earns coupons for every per coupons they
## hold, up to cap.

## Parameter key: how many coupons held make one lot.
const PER: String = "per"
## Parameter key: the coupons each lot pays.
const COUPONS: String = "coupons"
## Parameter key: the most coupons it pays at a Quota's end.
const CAP: String = "cap"


## Needs the lot size, what a lot pays and the cap.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([PER, COUPONS, CAP])


## Pays for each lot of held coupons, up to the cap, and shows it fired when it paid.
func set_end(context: SetContext) -> void:
	@warning_ignore("integer_division")
	var lots: int = context.coupons / parameters[PER]
	var paid: int = mini(lots * parameters[COUPONS], parameters[CAP])
	if paid > 0:
		context.add_coupons += paid
		memo.fire(paid)

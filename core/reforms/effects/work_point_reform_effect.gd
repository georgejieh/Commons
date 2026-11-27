class_name WorkPointReformEffect
extends ReformEffect
## Work-Point Reform: every Quota met pays more coupons.

const COUPONS: String = "coupons"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS])


func quota_coupons() -> int:
	return parameters[COUPONS]

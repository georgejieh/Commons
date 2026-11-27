class_name WorkPointReformEffect
extends ReformEffect
## Work-Point Reform: every Quota met pays more coupons.

## Parameter key: how many more coupons a Quota met pays.
const COUPONS: String = "coupons"


## Needs the extra coupons.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS])


## The extra coupons for every Quota met, from the parameter.
func quota_coupons() -> int:
	return parameters[COUPONS]

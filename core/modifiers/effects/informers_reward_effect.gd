class_name InformersRewardEffect
extends ModifierEffect
## Each villager whose lie an audit catches earns the player coupons (ADR 0032). The
## player's own caught lie earns nothing.

## Parameter key: the coupons each caught villager earns.
const COUPONS: String = "coupons"


## Needs the coupons per caught villager.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS])


## Pays the player for each villager caught, when the player holds it.
func need_settled(context: NeedContext) -> void:
	if holder_seat != context.player:
		return
	var paid: int = context.caught_villagers() * parameters[COUPONS]
	if paid > 0:
		context.coupons += paid
		memo.fire(paid)

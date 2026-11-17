class_name InformersRewardEffect
extends ModifierEffect
## Each villager whose lie an audit catches earns the player coupons (ADR 0032). The
## player's own caught lie earns nothing.

const COUPONS: String = "coupons"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS])


func need_settled(context: NeedContext) -> void:
	if holder_seat != context.player:
		return
	var paid: int = context.caught_villagers() * parameters[COUPONS]
	if paid > 0:
		context.coupons += paid
		memo.fire(paid)

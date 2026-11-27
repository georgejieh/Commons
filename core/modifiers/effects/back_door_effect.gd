class_name BackDoorEffect
extends ModifierEffect
## The first reroll of each black market visit costs nothing (ADR 0032).

## Only the first is free: the rule names one, so it is not a tunable number.
const FREE_REROLLS: int = 1


func shop_open(context: ShopContext) -> void:
	context.free_market_rerolls += FREE_REROLLS

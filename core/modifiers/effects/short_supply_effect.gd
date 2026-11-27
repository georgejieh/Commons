class_name ShortSupplyEffect
extends ModifierEffect
## The next state store shows fewer Cadres. It stacks with rationing (ADR 0023).

const CADRES: String = "cadres"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([CADRES])


func shop_open(context: ShopContext) -> void:
	context.cadre_cut += parameters[CADRES]

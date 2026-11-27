class_name ShortSupplyEffect
extends ModifierEffect
## The next state store shows fewer Cadres. It stacks with rationing (ADR 0023).

## Parameter key: how many Cadres fewer the state store shows.
const CADRES: String = "cadres"


## Needs the number of Cadres cut.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([CADRES])


## Cuts the Cadres the visit shows.
func shop_open(context: ShopContext) -> void:
	context.cadre_cut += parameters[CADRES]

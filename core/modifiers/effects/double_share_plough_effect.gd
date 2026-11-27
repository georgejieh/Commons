class_name DoubleSharePloughEffect
extends ModifierEffect
## Pair Runs may be as short as length pairs, for the holder's seat alone (ADR 0032, ADR
## 0039). Four cards of two neighbouring ranks were no hand before, so no legal play
## changes its reading. A seat without it answers one only with a Bomb or the Rocket.

## Parameter key: the shortest Pair Run the holder may play, in pairs.
const LENGTH: String = "length"


## Needs the shortest length.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([LENGTH])


## Lowers the holder's minimum Pair Run length to the parameter.
func build_ruleset(context: RulesetContext) -> void:
	context.params.min_pair_chain_length = mini(
		context.params.min_pair_chain_length, parameters[LENGTH]
	)

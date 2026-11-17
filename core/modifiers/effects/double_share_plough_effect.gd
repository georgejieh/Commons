class_name DoubleSharePloughEffect
extends ModifierEffect
## Pair Runs may be as short as length pairs, for every seat (ADR 0032). Four cards of
## two neighbouring ranks were no hand before, so no legal play changes its reading.

const LENGTH: String = "length"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([LENGTH])


func build_ruleset(context: RulesetContext) -> void:
	context.params.min_pair_chain_length = mini(
		context.params.min_pair_chain_length, parameters[LENGTH]
	)

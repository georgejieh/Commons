class_name ShockBrigadeEffect
extends ModifierEffect
## Straights may be as short as length, for every seat.

const LENGTH: String = "length"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([LENGTH])


func build_ruleset(context: RulesetContext) -> void:
	context.params.min_straight_length = mini(
		context.params.min_straight_length, parameters[LENGTH]
	)

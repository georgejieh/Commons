class_name ShockBrigadeEffect
extends ModifierEffect
## Straights may be as short as length, for the holder's seat alone (SeatScope, ADR
## 0039). A seat without it answers a shorter one only with a Bomb or the Rocket.

## Parameter key: the shortest Straight the holder may play, in cards.
const LENGTH: String = "length"


## Needs the shortest length.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([LENGTH])


## Lowers the holder's minimum Straight length to the parameter.
func build_ruleset(context: RulesetContext) -> void:
	context.params.min_straight_length = mini(
		context.params.min_straight_length, parameters[LENGTH]
	)

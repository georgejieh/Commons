class_name ShowTrialEffect
extends ModifierEffect
## The holder's Bombs and Rockets multiply their Zeal, given in hundredths, and each one
## the player plays adds Resentment.

## Parameter key: the factor a Bomb or Rocket's Zeal is multiplied by, in hundredths.
const TIMES_PERCENT_ZEAL: String = "times_percent_zeal"
## Parameter key: the Resentment each Bomb or Rocket the player plays adds.
const RESENTMENT: String = "resentment"


## Needs the Zeal factor and the Resentment.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_ZEAL, RESENTMENT])


## Multiplies the Zeal of a Bomb or Rocket.
func play_scored(context: PlayContext) -> void:
	if context.pattern.is_bomb():
		context.mul_zeal *= fraction(parameters[TIMES_PERCENT_ZEAL])


## Adds the Resentment for a Bomb or Rocket the player has played.
func turn_taken(context: TurnContext) -> void:
	if context.seat == holder_seat and context.seat == context.player and context.is_bomb():
		context.resentment += parameters[RESENTMENT]

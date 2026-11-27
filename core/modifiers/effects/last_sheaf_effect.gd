class_name LastSheafEffect
extends ModifierEffect
## The holder's play that empties their hand multiplies its Zeal, given in hundredths.

## Parameter key: the factor the Zeal is multiplied by, in hundredths.
const TIMES_PERCENT_ZEAL: String = "times_percent_zeal"


## Needs the Zeal factor.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_ZEAL])


## Multiplies the Zeal of the play that empties the hand.
func play_scored(context: PlayContext) -> void:
	if context.cards_left == 0:
		context.mul_zeal *= fraction(parameters[TIMES_PERCENT_ZEAL])

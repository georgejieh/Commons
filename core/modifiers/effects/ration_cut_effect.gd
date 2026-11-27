class_name RationCutEffect
extends ModifierEffect
## The holder's plays lose flat Zeal, given in hundredths.

## Parameter key: the flat Zeal each of the holder's plays loses, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"


## Needs the Zeal.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


## Takes the Zeal off each of the holder's plays.
func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat:
		context.add_zeal -= fraction(parameters[ZEAL_PERCENT])

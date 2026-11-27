class_name CanteenEffect
extends ModifierEffect
## Each Trio, Trio with a Single and Trio with a Pair gains flat Zeal, given in hundredths,
## for the holder and the holder's teammate (SeatScope, ADR 0039).

## Parameter key: the flat Zeal each Trio adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"
## The hand types it counts: Trio, Trio with a Single and Trio with a Pair.
const TRIOS: Array[Pattern.Type] = [
	Pattern.Type.TRIO, Pattern.Type.TRIO_SINGLE, Pattern.Type.TRIO_PAIR
]


## Needs the Zeal.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


## Adds the Zeal to a Trio play.
func play_scored(context: PlayContext) -> void:
	if TRIOS.has(context.pattern.type):
		context.add_zeal += fraction(parameters[ZEAL_PERCENT])

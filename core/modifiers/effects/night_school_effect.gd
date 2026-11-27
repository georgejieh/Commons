class_name NightSchoolEffect
extends ModifierEffect
## Singles and Pairs gain flat Zeal, given in hundredths (ADR 0032), for the holder and
## the holder's teammate (SeatScope, ADR 0039).

## Parameter key: the flat Zeal each Single or Pair adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"
## The hand types it counts: Single and Pair.
const SMALL_PLAYS: Array[Pattern.Type] = [Pattern.Type.SINGLE, Pattern.Type.PAIR]


## Needs the Zeal.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


## Adds the Zeal to a Single or a Pair.
func play_scored(context: PlayContext) -> void:
	if SMALL_PLAYS.has(context.pattern.type):
		context.add_zeal += fraction(parameters[ZEAL_PERCENT])

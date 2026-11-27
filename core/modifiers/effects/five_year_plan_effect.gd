class_name FiveYearPlanEffect
extends ModifierEffect
## Plays gain flat Zeal, given in hundredths, for each Year of the run so far, the Year in
## play counted (ADR 0032): one step in Year 1, eight in Year 8. For the holder and the
## holder's teammate (SeatScope, ADR 0039).

## Parameter key: the flat Zeal each Year adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"


## Needs the Zeal per Year.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


## Adds the Zeal once for every Year of the run so far.
func play_scored(context: PlayContext) -> void:
	context.add_zeal += fraction(parameters[ZEAL_PERCENT] * context.year)

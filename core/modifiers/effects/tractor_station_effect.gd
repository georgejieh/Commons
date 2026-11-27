class_name TractorStationEffect
extends ModifierEffect
## Airplanes, with or without wings, gain flat Zeal, given in hundredths (ADR 0032), for
## the holder and the holder's teammate (SeatScope, ADR 0039).

## Parameter key: the flat Zeal each Airplane adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"
## The hand types it counts: Airplane with no wings, with Singles and with Pairs.
const AIRPLANES: Array[Pattern.Type] = [
	Pattern.Type.AIRPLANE, Pattern.Type.AIRPLANE_SINGLES, Pattern.Type.AIRPLANE_PAIRS
]


## Needs the Zeal.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


## Adds the Zeal to an Airplane play.
func play_scored(context: PlayContext) -> void:
	if AIRPLANES.has(context.pattern.type):
		context.add_zeal += fraction(parameters[ZEAL_PERCENT])

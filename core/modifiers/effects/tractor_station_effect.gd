class_name TractorStationEffect
extends ModifierEffect
## Airplanes, with or without wings, gain flat Zeal, given in hundredths (ADR 0032), for
## the holder and the holder's teammate (SeatScope, ADR 0039).

const ZEAL_PERCENT: String = "zeal_percent"
const AIRPLANES: Array[Pattern.Type] = [
	Pattern.Type.AIRPLANE, Pattern.Type.AIRPLANE_SINGLES, Pattern.Type.AIRPLANE_PAIRS
]


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func play_scored(context: PlayContext) -> void:
	if AIRPLANES.has(context.pattern.type):
		context.add_zeal += fraction(parameters[ZEAL_PERCENT])

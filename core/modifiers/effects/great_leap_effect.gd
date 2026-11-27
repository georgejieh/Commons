class_name GreatLeapEffect
extends ModifierEffect
## Boss: every play the holder makes gains flat Zeal, given in hundredths. The run
## loop doubles the Quota from the definition's quota_percent.

## Parameter key: the flat Zeal each of the holder's plays gains, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"
## Parameter key: the percent the run loop sets the Quota to; this script does not read it.
const QUOTA_PERCENT: String = "quota_percent"


## Needs the Zeal and the Quota percent.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT, QUOTA_PERCENT])


## Adds the Zeal to each of the holder's plays.
func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat:
		context.add_zeal += fraction(parameters[ZEAL_PERCENT])

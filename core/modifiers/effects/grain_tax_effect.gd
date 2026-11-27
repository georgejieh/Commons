class_name GrainTaxEffect
extends ModifierEffect
## A share of what the holder banks each round is taken before it counts toward the
## Quota, rounded against them (ADR 0023).

## Parameter key: the share of the holder's bank taken, in percent.
const PERCENT: String = "percent"


## Needs the percent.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([PERCENT])


## Adds its percent to the tax taken from what the holder banks.
func round_end(context: RoundContext) -> void:
	context.tax_percent += parameters[PERCENT]

class_name GrainTaxEffect
extends ModifierEffect
## A share of what the holder banks each round is taken before it counts toward the
## Quota, rounded against them (ADR 0023).

const PERCENT: String = "percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([PERCENT])


func round_end(context: RoundContext) -> void:
	context.tax_percent += parameters[PERCENT]

class_name PrizeExhibitEffect
extends ModifierEffect
## Model cards the holder scores score their printed Grain times a multiplier in
## hundredths, in place of what Model alone gives (ADR 0032). Flat Grain other hooks add
## is never multiplied.

## Parameter key: the factor a Model card's printed Grain is multiplied by, in hundredths.
const TIMES_PERCENT_GRAIN: String = "times_percent_grain"


## Needs the factor.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_GRAIN])


## Sets a scored Model card's Grain to its printed Grain times the factor.
func card_scored(context: CardContext) -> void:
	if context.card.enhancement_id() != CardInstance.MODEL:
		return
	var wanted: float = fraction(context.printed_grain * parameters[TIMES_PERCENT_GRAIN])
	context.grain += wanted - context.own_grain

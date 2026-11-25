class_name PrizeExhibitEffect
extends ModifierEffect
## Model cards the holder scores score their printed Grain times a multiplier in
## hundredths, in place of what Model alone gives (ADR 0032). Flat Grain other hooks add
## is never multiplied.

const TIMES_PERCENT_GRAIN: String = "times_percent_grain"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([TIMES_PERCENT_GRAIN])


func card_scored(context: CardContext) -> void:
	if context.card.enhancement_id() != CardInstance.MODEL:
		return
	var wanted: float = context.printed_grain * parameters[TIMES_PERCENT_GRAIN] / 100.0
	context.grain += wanted - context.own_grain

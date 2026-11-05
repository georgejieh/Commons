class_name TypeShareEffect
extends ModifierEffect
## The holder's plays of one hand type keep only a percentage of their Grain, counting
## Grain that Cadres added, or of their finished total.

const TYPE: String = "type"
const PERCENT: String = "percent"
## 1 cuts the finished total; 0 cuts Grain only.
const WHOLE: String = "whole"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([TYPE, PERCENT, WHOLE])


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat or context.pattern.type != parameters[TYPE]:
		return
	var share: float = parameters[PERCENT] / 100.0
	if parameters[WHOLE] == 1:
		context.total_scale *= share
	else:
		context.add_grain -= (context.grain + context.add_grain) * (1.0 - share)

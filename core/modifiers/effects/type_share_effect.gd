class_name TypeShareEffect
extends ModifierEffect
## The holder's plays of one hand type keep only a percentage of their Grain, counting
## Grain that Cadres added, or of their finished total.

## Parameter key: the hand type it cuts.
const TYPE: String = "type"
## Parameter key: the share kept, in percent.
const PERCENT: String = "percent"
## 1 cuts the finished total; 0 cuts Grain only.
const WHOLE: String = "whole"


## Needs the hand type, the share kept and whether it cuts the whole total.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([TYPE, PERCENT, WHOLE])


## Cuts the holder's plays of the type to the share, on the Grain or on the finished total.
func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat or context.pattern.type != parameters[TYPE]:
		return
	var share: float = fraction(parameters[PERCENT])
	if parameters[WHOLE] == 1:
		context.total_scale *= share
	else:
		context.add_grain -= (context.grain + context.add_grain) * (1.0 - share)

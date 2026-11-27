class_name RequisitionEffect
extends ModifierEffect
## Boss: the holder's Bombs and Rockets score nothing.


## Zeroes the score of the holder's Bombs and Rockets.
func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat:
		return
	if context.pattern.is_bomb():
		context.total_scale = 0.0

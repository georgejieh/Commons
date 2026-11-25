class_name RequisitionEffect
extends ModifierEffect
## Boss: the holder's Bombs and Rockets score nothing.


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat:
		return
	if context.pattern.type == Pattern.Type.BOMB or context.pattern.type == Pattern.Type.ROCKET:
		context.total_scale = 0.0

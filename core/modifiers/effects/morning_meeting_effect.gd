class_name MorningMeetingEffect
extends ModifierEffect
## The holder's first play of each round scores nothing.


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat and context.plays_before == 0:
		context.total_scale = 0.0

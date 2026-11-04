class_name MorningMeetingEffect
extends ModifierEffect
## The holder's first play of each round scores nothing.


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat and context.plays_before == 0:
		context.mul_zeal = 0.0

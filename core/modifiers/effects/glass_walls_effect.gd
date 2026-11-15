class_name GlassWallsEffect
extends ModifierEffect
## Both other seats see the holder's hand, through their own views (ADR 0023).


func build_ruleset(context: RulesetContext) -> void:
	if context.seat == holder_seat:
		context.params.hand_shown = true

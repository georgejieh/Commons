class_name NightShiftEffect
extends ModifierEffect
## On the holder's first chance to pass each round, they must play if anything they hold
## beats the table. With nothing that does, they pass and the rule is spent (ADR 0023).


func build_ruleset(context: RulesetContext) -> void:
	if context.seat == holder_seat:
		context.params.must_answer_once = true

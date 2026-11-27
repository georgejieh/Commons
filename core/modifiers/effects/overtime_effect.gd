class_name OvertimeEffect
extends ModifierEffect
## The holder banks a round's score only if their side goes out first (ADR 0023).


## Voids the holder's bank when their side lost the round.
func round_end(context: RoundContext) -> void:
	if context.side_lost(holder_seat):
		context.bank_voided = true

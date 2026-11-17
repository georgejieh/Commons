class_name OpenAccountsEffect
extends ModifierEffect
## Each round the player declares, as a peasant, no more than their true need, their
## Resentment falls (ADR 0032). A round as landlord declares nothing and counts for
## nothing. The fall stops at 0, on Resentment's one path down.

const RESENTMENT: String = "resentment"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RESENTMENT])


func need_settled(context: NeedContext) -> void:
	if holder_seat != context.player or not context.declared_honestly():
		return
	context.resentment_fall += parameters[RESENTMENT]
	memo.fire(parameters[RESENTMENT])

class_name OpenAccountsEffect
extends ModifierEffect
## Each round the player declares, as a peasant, no more than their true need, their
## Resentment falls (ADR 0032). A round as landlord declares nothing and counts for
## nothing. The fall stops at 0, on Resentment's one path down.

## Parameter key: the Resentment that falls for an honest declaration.
const RESENTMENT: String = "resentment"


## Needs the Resentment.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RESENTMENT])


## Lowers Resentment when the player declared honestly as a peasant.
func need_settled(context: NeedContext) -> void:
	if holder_seat != context.player or not context.declared_honestly():
		return
	context.resentment_fall += parameters[RESENTMENT]
	memo.fire(parameters[RESENTMENT])

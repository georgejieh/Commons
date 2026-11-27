class_name AnonymousLetterEffect
extends CampaignEffect
## On the player's turn, before they play: the next seat must pass if it is answering the
## player's play this trick. A pass, or a play that ends the round, spends it for nothing.

## Parameter key: the Resentment the Letter costs.
const RESENTMENT: String = "resentment"


## Needs the Resentment it costs.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RESENTMENT])


## Refuses a second Letter in the same turn.
func check(context: CampaignContext) -> Reason:
	if context.flags.letter_armed:
		return Reason.ALREADY_USED
	return Reason.OK


## Arms the Letter and adds its Resentment.
func apply(context: CampaignContext) -> void:
	context.flags.letter_armed = true
	context.resent(parameters[RESENTMENT])

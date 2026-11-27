class_name OverfulfillmentEffect
extends CampaignEffect
## As landlord, after taking the kitty and before the first play: this round's bank is
## multiplied by win_times if the landlord wins, and voided if it loses.

## Parameter key: the factor a win multiplies the bank by.
const WIN_TIMES: String = "win_times"


## Needs the win factor.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([WIN_TIMES])


## Refuses a peasant, and a second stake in the same round.
func check(context: CampaignContext) -> Reason:
	if context.round_state.landlord() != context.player:
		return Reason.NOT_LANDLORD
	if context.flags.staked:
		return Reason.ALREADY_USED
	return Reason.OK


## Stakes the round's bank at the win factor.
func apply(context: CampaignContext) -> void:
	context.flags.staked = true
	context.flags.win_times = parameters[WIN_TIMES]

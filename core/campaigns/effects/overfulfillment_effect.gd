class_name OverfulfillmentEffect
extends CampaignEffect
## As landlord, after taking the kitty and before the first play: this round's bank is
## multiplied by win_times if the landlord wins, and voided if it loses.

const WIN_TIMES: String = "win_times"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([WIN_TIMES])


func check(context: CampaignContext) -> Reason:
	if context.round_state.landlord() != context.player:
		return Reason.NOT_LANDLORD
	if context.flags.staked:
		return Reason.ALREADY_USED
	return Reason.OK


func apply(context: CampaignContext) -> void:
	context.flags.staked = true
	context.flags.win_times = parameters[WIN_TIMES]

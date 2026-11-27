class_name MutualAidEffect
extends CampaignEffect
## As a peasant, before the first play: the player's chosen cards go to their teammate,
## and the teammate's bot hands back as many of its own, chosen before it sees the
## player's, through the bot interface. Both hands keep their size.


## Refuses for the landlord, who has no teammate.
func check(context: CampaignContext) -> Reason:
	if context.round_state.landlord() == context.player:
		return Reason.NOT_PEASANT
	return Reason.OK


## Trades the chosen cards for as many the teammate's bot chooses to give.
func apply(context: CampaignContext) -> void:
	var mate: int = Seats.teammate(context.player, context.round_state.landlord())
	var gift: Array[int] = Bot.choose_gift(
		context.round_state.view_for(mate), context.seat_table(mate), context.card_ids.size()
	)
	context.trade(mate, context.card_ids, gift)

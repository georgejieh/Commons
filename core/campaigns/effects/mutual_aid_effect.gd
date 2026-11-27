class_name MutualAidEffect
extends CampaignEffect
## As a peasant, before the first play: the player's chosen cards go to their teammate,
## and the teammate's bot hands back as many of its own, chosen before it sees the
## player's, through the bot interface. Both hands keep their size.


func check(context: CampaignContext) -> Reason:
	if context.round_state.landlord() == context.player:
		return Reason.NOT_PEASANT
	return Reason.OK


func apply(context: CampaignContext) -> void:
	var mate: int = teammate(context)
	var gift: Array[int] = Bot.choose_gift(
		context.round_state.view_for(mate), context.seat_table(mate), context.card_ids.size()
	)
	context.trade(mate, context.card_ids, gift)


## The other peasant: the seat that is neither the player nor the landlord.
static func teammate(context: CampaignContext) -> int:
	var landlord: int = context.round_state.landlord()
	for seat: int in Seats.COUNT:
		if seat != context.player and seat != landlord:
			return seat
	return Seats.NONE

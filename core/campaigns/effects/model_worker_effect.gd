class_name ModelWorkerEffect
extends CampaignEffect
## Model Worker (ADR 0029): before the first play, one rank drawn from 3 to 2 is wild for
## the player's seat alone this round (ADR 0039), beside any already wild. With two wild
## it cannot be used. The draw is on the deal stream, as Mass Line's is, and the rules
## change at once, so the round in play reads it before the next action.


func check(context: CampaignContext) -> Reason:
	return Reason.OK if RunWild.has_room(context.state) else Reason.WILD_FULL


func apply(context: CampaignContext) -> void:
	var rank: int = RunWild.add(context.state, context.state.streams.stream(RandomStreams.DEAL))
	context.add_event(RunWild.event(context.state, rank))
	context.table.set_wild_ranks(context.state.wild_ranks, context.player)
	context.table.refresh()

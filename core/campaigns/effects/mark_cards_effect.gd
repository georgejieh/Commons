class_name MarkCardsEffect
extends CampaignEffect
## The Campaigns that mark cards in the player's hand for the rest of the run (ADR 0021,
## ADR 0041): Registration Drive stamps them as the player's, and Model Harvest and the
## others give them an enhancement, in place of any other they carry. A card that already
## carries that mark is refused, so a use is never wasted on it.

## The enhancement given, or CardInstance.NO_ID for the player's stamp.
var enhancement: String = CardInstance.NO_ID


func _init(enhancement_id: String) -> void:
	enhancement = enhancement_id


func check(context: CampaignContext) -> Reason:
	for card: CardInstance in context.hand():
		if not context.card_ids.has(card.id()):
			continue
		var marked: bool = (
			card.owner_stamp() == context.player
			if enhancement == CardInstance.NO_ID
			else card.enhancement_id() == enhancement
		)
		if marked:
			return Reason.ALREADY_MARKED
	return Reason.OK


func apply(context: CampaignContext) -> void:
	context.mark_chosen(enhancement)

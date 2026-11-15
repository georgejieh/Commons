class_name MarkCardsEffect
extends CampaignEffect
## Model Harvest and Registration Drive: the chosen cards in the player's hand take a
## mark for the rest of the run, Model or the player's stamp. A card that already carries
## that mark is refused, so a use is never wasted on it.

var model: bool = false


func _init(makes_model: bool) -> void:
	model = makes_model


func check(context: CampaignContext) -> Reason:
	for card: CardInstance in context.hand():
		if not context.card_ids.has(card.id()):
			continue
		var marked: bool = (
			card.enhancement_id() == CardInstance.MODEL
			if model
			else card.owner_stamp() == context.player
		)
		if marked:
			return Reason.ALREADY_MARKED
	return Reason.OK


func apply(context: CampaignContext) -> void:
	context.mark_chosen(model)

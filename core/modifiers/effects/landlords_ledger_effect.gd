class_name LandlordsLedgerEffect
extends ModifierEffect
## While the holder is landlord, kitty cards score their Grain twice.

## The round's deal. The kitty is read from it when a card scores, not when the deal
## hook runs, because a later deal hook may still change the kitty.
var _deal: DealResult = null


func on_deal(context: DealContext) -> void:
	_deal = context.deal


func card_scored(context: CardContext) -> void:
	if context.seat == holder_seat and context.is_landlord and _in_kitty(context.card.id()):
		context.grain *= 2.0


func _in_kitty(card_id: int) -> bool:
	if _deal == null:
		return false
	for card: CardInstance in _deal.kitty:
		if card.id() == card_id:
			return true
	return false

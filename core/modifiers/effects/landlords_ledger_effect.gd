class_name LandlordsLedgerEffect
extends ModifierEffect
## While the holder is landlord, kitty cards score their Grain twice.

## The round's deal. The kitty is read from it when a card scores, not when the deal
## hook runs, because a later deal hook may still change the kitty.
var _deal: DealResult = null


## Remembers the round's deal, to read its kitty when a card scores.
func on_deal(context: DealContext) -> void:
	_deal = context.deal


## Takes the deal when the Cadre is handed back into the round after the deal.
func handed_back(deal: DealResult) -> void:
	_deal = deal


## Doubles the Grain of a kitty card the landlord holder plays.
func card_scored(context: CardContext) -> void:
	if context.is_landlord and _in_kitty(context.card.id()):
		context.grain *= 2.0


func _in_kitty(card_id: int) -> bool:
	if _deal == null:
		return false
	for card: CardInstance in _deal.kitty:
		if card.id() == card_id:
			return true
	return false

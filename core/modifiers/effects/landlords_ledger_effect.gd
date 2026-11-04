class_name LandlordsLedgerEffect
extends ModifierEffect
## While the holder is landlord, kitty cards score their Grain twice.

var _kitty_ids: Dictionary[int, bool] = {}


func on_deal(context: DealContext) -> void:
	_kitty_ids.clear()
	for card: CardInstance in context.deal.kitty:
		_kitty_ids[card.id()] = true


func card_scored(context: CardContext) -> void:
	if context.seat == holder_seat and context.is_landlord and _kitty_ids.has(context.card.id()):
		context.grain *= 2.0

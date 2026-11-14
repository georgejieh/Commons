class_name StruggleSessionEffect
extends ModifierEffect
## Boss (P4.7): at each deal the holder's highest card is confiscated into the kitty, in
## exchange for the kitty's lowest card, so every card stays in play.


func on_deal(context: DealContext) -> void:
	var hand: Hand = context.deal.hands[holder_seat]
	if hand.size() == 0 or context.deal.kitty.is_empty():
		return
	var highest: CardInstance = hand.cards()[0]
	for card: CardInstance in hand.cards():
		if _above(card, highest):
			highest = card
	var lowest: int = 0
	for index: int in context.deal.kitty.size():
		if _above(context.deal.kitty[lowest], context.deal.kitty[index]):
			lowest = index
	var given: CardInstance = context.deal.kitty[lowest]
	hand.remove(highest.id())
	hand.add(given)
	context.deal.kitty[lowest] = highest


## Rank first, then ID, so the choice never depends on hand order.
static func _above(card: CardInstance, other: CardInstance) -> bool:
	if card.base_rank() != other.base_rank():
		return card.base_rank() > other.base_rank()
	return card.id() > other.id()

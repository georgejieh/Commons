class_name HandicapEffect
extends ModifierEffect
## Boss (ADR 0043): each deal, cards drawn at random from the holder's hand are set aside
## face up for the round, more of them as the Years pass. Every seat sees them, so the
## round's count of its cards drops them for every seat.

## The cards set aside in Year 1.
const CARDS: String = "cards"
## One more card is set aside every this many Years.
const YEARS_PER_CARD: String = "years_per_card"


## Needs the cards set aside in Year 1 and the Years it takes to add one.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([CARDS, YEARS_PER_CARD])


## How many cards a deal sets aside in the Year.
static func count_at(values: Dictionary[String, int], year: int) -> int:
	@warning_ignore("integer_division")
	return values[CARDS] + maxi(year - 1, 0) / maxi(values[YEARS_PER_CARD], 1)


## Drawn from the hand in card-ID order, so the draw never depends on how the hand is held.
func on_deal(context: DealContext) -> void:
	var hand: Hand = context.deal.hands[holder_seat]
	var ids: Array[int] = []
	for card: CardInstance in hand.cards():
		ids.append(card.id())
	ids.sort()
	for _card: int in mini(count_at(parameters, context.year), ids.size()):
		var pick: int = context.stream.next_int(0, ids.size() - 1)
		var card: CardInstance = hand.remove(ids[pick])
		ids.remove_at(pick)
		context.deal.set_aside.append(card)
		context.deal.deck_counts[card.base_rank()] -= 1

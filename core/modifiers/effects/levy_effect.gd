class_name LevyEffect
extends ModifierEffect
## Each round, after the kitty and before the plot swap: the holder's highest cards go to
## the seat on their left, which hands back as many of its lowest (ADR 0023). Highest
## and lowest are by each seat's own rank order (CardPick).

## Parameter key: how many cards each side hands over.
const CARDS: String = "cards"


## Needs the number of cards.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([CARDS])


## Trades the holder's highest cards for the lowest of the seat on its left.
func round_start(context: RoundContext) -> void:
	if context.round_state == null:
		return
	var left: int = Seats.left(holder_seat)
	var count: int = parameters[CARDS]
	var given: Array[int] = CardPick.extremes(
		context.round_state.view_for(holder_seat).own_cards,
		context.table.map_for(holder_seat),
		true,
		count
	)
	var taken: Array[int] = CardPick.extremes(
		context.round_state.view_for(left).own_cards, context.table.map_for(left), false, count
	)
	context.trade(holder_seat, given, left, taken)

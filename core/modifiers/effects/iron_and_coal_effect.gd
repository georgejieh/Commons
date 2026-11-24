class_name IronAndCoalEffect
extends ModifierEffect
## Every scored spade and club adds flat Grain (ADR 0032), for the holder and the holder's
## teammate (SeatScope, ADR 0039). Jokers have no suit.

const GRAIN: String = "grain"
## Suits in deck order: spade, heart, club, diamond.
const SPADE: int = 0
const CLUB: int = 2


func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


func card_scored(context: CardContext) -> void:
	var suit: int = context.card.suit()
	if suit == SPADE or suit == CLUB:
		context.grain += parameters[GRAIN]

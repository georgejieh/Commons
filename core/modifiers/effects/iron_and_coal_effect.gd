class_name IronAndCoalEffect
extends ModifierEffect
## Every scored spade and club adds flat Grain (ADR 0032), for the holder and the holder's
## teammate (SeatScope, ADR 0039). Jokers have no suit.

## Parameter key: the flat Grain each spade and club adds.
const GRAIN: String = "grain"
## The spade's suit index; suits run in deck order: spade, heart, club, diamond.
const SPADE: int = 0
## The club's suit index.
const CLUB: int = 2


## Needs the Grain.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


## Adds the Grain to a scored spade or club.
func card_scored(context: CardContext) -> void:
	var suit: int = context.card.suit()
	if suit == SPADE or suit == CLUB:
		context.grain += parameters[GRAIN]

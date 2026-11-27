class_name RedBannerEffect
extends ModifierEffect
## Every scored heart and diamond adds flat Grain, for the holder and the holder's
## teammate (SeatScope, ADR 0039). Jokers have no suit.

## Parameter key: the flat Grain each heart and diamond adds.
const GRAIN: String = "grain"
## The heart's suit index; suits run in deck order: spade, heart, club, diamond.
const HEART: int = 1
## The diamond's suit index.
const DIAMOND: int = 3


## Needs the Grain.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


## Adds the Grain to a scored heart or diamond.
func card_scored(context: CardContext) -> void:
	var suit: int = context.card.suit()
	if suit == HEART or suit == DIAMOND:
		context.grain += parameters[GRAIN]

class_name RedBannerEffect
extends ModifierEffect
## Every scored heart and diamond adds flat Grain, for whoever scores it. Jokers have no
## suit.

const GRAIN: String = "grain"
## Suits in deck order: spade, heart, club, diamond.
const HEART: int = 1
const DIAMOND: int = 3


func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


func card_scored(context: CardContext) -> void:
	var suit: int = context.card.suit()
	if suit == HEART or suit == DIAMOND:
		context.grain += parameters[GRAIN]

class_name LoudspeakerEffect
extends ModifierEffect
## The holder's 2s and jokers played as Singles gain flat Zeal, given in hundredths (ADR
## 0032). The card is read by its printed rank, so a wild card standing in as a 2 is not
## one.

## Parameter key: the flat Zeal a 2 or joker Single adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"


## Needs the Zeal.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


## Adds the Zeal to a Single whose card is printed a 2 or a joker.
func play_scored(context: PlayContext) -> void:
	if context.pattern.type != Pattern.Type.SINGLE:
		return
	if context.body_cards.size() == 1 and context.body_cards[0] >= Ranks.TWO:
		context.add_zeal += fraction(parameters[ZEAL_PERCENT])

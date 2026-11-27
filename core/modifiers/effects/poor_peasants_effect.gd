class_name PoorPeasantsEffect
extends ModifierEffect
## Scored cards printed from low_rank to high_rank score their own Grain times a
## multiplier in hundredths, for the holder and the holder's teammate (SeatScope, ADR
## 0039). Own Grain is the printed Grain,
## raised if the card is Model, so flat Grain other hooks add is never multiplied.

## Parameter key: the lowest rank it multiplies.
const LOW_RANK: String = "low_rank"
## Parameter key: the highest rank it multiplies.
const HIGH_RANK: String = "high_rank"
## Parameter key: the factor a card's own Grain is multiplied by, in hundredths.
const TIMES_PERCENT_GRAIN: String = "times_percent_grain"


## Needs the rank range and the factor.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([LOW_RANK, HIGH_RANK, TIMES_PERCENT_GRAIN])


## The two bounds of the range must be valid ranks.
func rank_parameters() -> PackedStringArray:
	return PackedStringArray([LOW_RANK, HIGH_RANK])


## Adds the extra of the card's own Grain for a scored card in the rank range.
func card_scored(context: CardContext) -> void:
	var rank: int = context.card.base_rank()
	if rank >= parameters[LOW_RANK] and rank <= parameters[HIGH_RANK]:
		context.grain += fraction(context.own_grain * (parameters[TIMES_PERCENT_GRAIN] - 100))

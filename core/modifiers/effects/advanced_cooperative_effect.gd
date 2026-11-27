class_name AdvancedCooperativeEffect
extends ModifierEffect
## Every scored card printed from low_rank to high_rank adds flat Grain (ADR 0032), for the
## holder and the holder's teammate (SeatScope, ADR 0039).

## Parameter key: the lowest rank that adds Grain.
const LOW_RANK: String = "low_rank"
## Parameter key: the highest rank that adds Grain.
const HIGH_RANK: String = "high_rank"
## Parameter key: the flat Grain each such card adds.
const GRAIN: String = "grain"


## Needs the rank range and the Grain.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([LOW_RANK, HIGH_RANK, GRAIN])


## The two bounds of the range must be valid ranks.
func rank_parameters() -> PackedStringArray:
	return PackedStringArray([LOW_RANK, HIGH_RANK])


## Adds the Grain to a scored card printed in the rank range.
func card_scored(context: CardContext) -> void:
	var rank: int = context.card.base_rank()
	if rank >= parameters[LOW_RANK] and rank <= parameters[HIGH_RANK]:
		context.grain += parameters[GRAIN]

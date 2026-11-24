class_name AdvancedCooperativeEffect
extends ModifierEffect
## Every scored card printed from low_rank to high_rank adds flat Grain (ADR 0032), for the
## holder and the holder's teammate (SeatScope, ADR 0039).

const LOW_RANK: String = "low_rank"
const HIGH_RANK: String = "high_rank"
const GRAIN: String = "grain"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([LOW_RANK, HIGH_RANK, GRAIN])


func rank_parameters() -> PackedStringArray:
	return PackedStringArray([LOW_RANK, HIGH_RANK])


func card_scored(context: CardContext) -> void:
	var rank: int = context.card.base_rank()
	if rank >= parameters[LOW_RANK] and rank <= parameters[HIGH_RANK]:
		context.grain += parameters[GRAIN]

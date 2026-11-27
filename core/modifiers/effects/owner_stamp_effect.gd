class_name OwnerStampEffect
extends ModifierEffect
## Cards stamped with the holder's mark score extra Grain (P4.9). Only the holder gets
## it: dealt to anyone else a stamped card is plain, unless for_anyone is 1, when it
## scores for whoever plays it.

const GRAIN: String = "grain"
const FOR_ANYONE: String = "for_anyone"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN, FOR_ANYONE])


func card_scored(context: CardContext) -> void:
	if context.card.owner_stamp() != holder_seat:
		return
	if context.seat == holder_seat or parameters[FOR_ANYONE] == 1:
		context.grain += parameters[GRAIN]

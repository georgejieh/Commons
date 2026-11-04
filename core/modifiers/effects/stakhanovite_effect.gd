class_name StakhanoviteEffect
extends ModifierEffect
## The holder's Straights gain Zeal for each card beyond the shortest legal length.

const ZEAL_PER_CARD: String = "zeal_per_card"
const BASE_LENGTH: String = "base_length"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PER_CARD, BASE_LENGTH])


func play_scored(context: PlayContext) -> void:
	if context.seat != holder_seat or context.pattern.type != Pattern.Type.STRAIGHT:
		return
	var extra: int = maxi(0, context.pattern.card_count - parameters[BASE_LENGTH])
	context.add_zeal += extra * parameters[ZEAL_PER_CARD]

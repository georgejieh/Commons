class_name PromotionEffect
extends ModifierEffect
## Moves one rank to just above another in the holder's map alone (SeatScope, ADR 0039),
## and the ranks between shift to make room, so order holds whatever the map looked like
## before.

const RANK: String = "rank"
const ABOVE: String = "above"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, ABOVE])


func rank_parameters() -> PackedStringArray:
	return required_parameters()


func build_rank_map(context: RankMapContext) -> void:
	RankShift.move_above(context.rank_map, parameters[RANK], parameters[ABOVE], context.step)

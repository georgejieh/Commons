class_name PromotionEffect
extends ModifierEffect
## Moves one rank to just above another, and the ranks between shift to make room, so
## order holds whatever the map looked like before.

const RANK: String = "rank"
const ABOVE: String = "above"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, ABOVE])


func rank_parameters() -> PackedStringArray:
	return required_parameters()


func build_rank_map(context: RankMapContext) -> void:
	var low: int = context.rank_map[parameters[RANK]]
	var high: int = context.rank_map[parameters[ABOVE]]
	if low == high:
		return
	for rank: int in Ranks.COUNT:
		var value: int = context.rank_map[rank]
		if value > low and value <= high:
			context.rank_map[rank] = value - 1
		elif value > high and value < low:
			context.rank_map[rank] = value + 1
	context.rank_map[parameters[RANK]] = high if low < high else high + 1

class_name PromotionEffect
extends ModifierEffect
## Lifts one rank just above another, and everything between steps down to make room.

const RANK: String = "rank"
const ABOVE: String = "above"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, ABOVE])


func build_rank_map(context: RankMapContext) -> void:
	var low: int = context.rank_map[parameters[RANK]]
	var high: int = context.rank_map[parameters[ABOVE]]
	for rank: int in Ranks.COUNT:
		var value: int = context.rank_map[rank]
		if value > low and value <= high:
			context.rank_map[rank] = value - 1
	context.rank_map[parameters[RANK]] = high

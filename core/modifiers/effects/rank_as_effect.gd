class_name RankAsEffect
extends ModifierEffect
## The holder's cards of one rank compare as another rank.

const RANK: String = "rank"
const RANKS_AS: String = "ranks_as"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, RANKS_AS])


func rank_parameters() -> PackedStringArray:
	return required_parameters()


func build_rank_map(context: RankMapContext) -> void:
	if context.seat == holder_seat:
		context.rank_map[parameters[RANK]] = context.rank_map[parameters[RANKS_AS]]

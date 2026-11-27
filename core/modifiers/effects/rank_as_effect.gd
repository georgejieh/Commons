class_name RankAsEffect
extends ModifierEffect
## The holder's cards of one rank compare as another rank.

## Parameter key: the rank that is moved.
const RANK: String = "rank"
## Parameter key: the rank it compares as.
const RANKS_AS: String = "ranks_as"


## Needs the rank and the rank it stands as.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, RANKS_AS])


## Both ranks must be valid ranks.
func rank_parameters() -> PackedStringArray:
	return required_parameters()


## Gives the holder's cards of the rank the other rank's place in the order.
func build_rank_map(context: RankMapContext) -> void:
	if context.seat == holder_seat:
		context.rank_map[parameters[RANK]] = context.rank_map[parameters[RANKS_AS]]

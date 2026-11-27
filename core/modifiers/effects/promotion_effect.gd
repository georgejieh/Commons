class_name PromotionEffect
extends ModifierEffect
## Moves one rank to just above another in the holder's map alone (SeatScope, ADR 0039),
## and the ranks between shift to make room, so order holds whatever the map looked like
## before.

## Parameter key: the rank that moves.
const RANK: String = "rank"
## Parameter key: the rank it moves to just above.
const ABOVE: String = "above"


## Needs the rank and the rank to pass.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, ABOVE])


## Both ranks must be valid ranks.
func rank_parameters() -> PackedStringArray:
	return required_parameters()


## Moves the rank to just above the other in the holder's map.
func build_rank_map(context: RankMapContext) -> void:
	RankShift.move_above(context.rank_map, parameters[RANK], parameters[ABOVE], context.step)

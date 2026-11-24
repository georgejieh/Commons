class_name RankMapContext
extends RefCounted
## Passed to the build rank map hook.

## The seat being built.
var seat: int
var landlord: int
## True once a bomb has been played in this trick.
var trick_bombed: bool
## Bit per base rank: the ranks whose every card in the seat's hand carries the seat's
## own stamp. 0 outside a round.
var stamped: int = 0
## Effective rank per base rank, to edit.
var rank_map: PackedByteArray
## The gap between neighbouring printed ranks in rank_map: 1 for a seat's own order,
## Standing.STEP for its standings, where a moved rank fits between two others. An effect
## hands it to RankShift and ReversedRanks and never needs to read it.
var step: int = 1


func _init(
	seat_value: int,
	landlord_value: int,
	trick_bombed_value: bool,
	rank_map_value: PackedByteArray,
) -> void:
	seat = seat_value
	landlord = landlord_value
	trick_bombed = trick_bombed_value
	rank_map = rank_map_value

class_name RankMapContext
extends RefCounted
## Passed to the build rank map hook.

## The seat being built.
var seat: int
var landlord: int
## True once a bomb has been played in this trick.
var trick_bombed: bool
## Effective rank per base rank, to edit.
var rank_map: PackedByteArray


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

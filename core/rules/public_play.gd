class_name PublicPlay
extends RefCounted
## One entry in the table's history. A pass is a pass pattern and no cards.

## The seat that played or passed.
var seat: int
## What the seat played; a pass pattern for a pass.
var pattern: Pattern
## Rank counts, which everyone at the table saw.
var counts: PackedByteArray


func _init(playing_seat: int, played: Pattern, played_counts: PackedByteArray) -> void:
	seat = playing_seat
	pattern = played
	counts = played_counts


## An independent copy, so a view can never reach the round's own history.
func copy() -> PublicPlay:
	return PublicPlay.new(seat, pattern.copy(), counts.duplicate())

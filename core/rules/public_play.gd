class_name PublicPlay
extends RefCounted
## One entry in the table's history. A pass is a pass pattern and no cards.

var seat: int
var pattern: Pattern
## Rank counts, which everyone at the table saw.
var counts: PackedByteArray


func _init(playing_seat: int, played: Pattern, played_counts: PackedByteArray) -> void:
	seat = playing_seat
	pattern = played
	counts = played_counts

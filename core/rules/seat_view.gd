class_name SeatView
extends RefCounted
## All a bot ever receives: the public view plus copies of its own hand.

var seat: int
var public: PublicView
var own_counts: PackedByteArray
var own_cards: Array[CardInstance]


func _init(
	viewing_seat: int, public_view: PublicView, counts: PackedByteArray, cards: Array[CardInstance]
) -> void:
	seat = viewing_seat
	public = public_view
	own_counts = counts
	own_cards = cards

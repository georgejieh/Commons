class_name PublicView
extends RefCounted
## Everything any seat may know about a round. It holds copies of values and no link
## back to the round, so nothing here can reach another seat's hand.

var landlord: int
var seat_to_act: int
## Cards left per seat.
var remaining: PackedInt32Array
var history: Array[PublicPlay]
## Rank counts of the revealed kitty.
var kitty_counts: PackedByteArray
## The play to beat, or null when the seat to act leads.
var current_play: Pattern
## Per seat, the last call of 2 or 1 cards left, or 0 before any.
var announced: PackedInt32Array


func _init(
	landlord_seat: int,
	acting_seat: int,
	sizes: PackedInt32Array,
	plays: Array[PublicPlay],
	kitty: Array[CardInstance],
	to_beat: Pattern,
	calls: PackedInt32Array
) -> void:
	landlord = landlord_seat
	seat_to_act = acting_seat
	remaining = sizes
	history = plays.duplicate()
	kitty_counts = PackedByteArray()
	kitty_counts.resize(Ranks.COUNT)
	for card: CardInstance in kitty:
		kitty_counts[card.base_rank()] += 1
	current_play = to_beat
	announced = calls.duplicate()

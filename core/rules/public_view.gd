class_name PublicView
extends RefCounted
## Everything any seat may know about a round. Every field is an independent copy with
## no link back to the round, so changing a view changes nothing and reaches no hand.

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
	history = []
	for play: PublicPlay in plays:
		history.append(play.copy())
	kitty_counts = PackedByteArray()
	kitty_counts.resize(Ranks.COUNT)
	for card: CardInstance in kitty:
		kitty_counts[card.base_rank()] += 1
	current_play = null if to_beat == null else to_beat.copy()
	announced = calls.duplicate()

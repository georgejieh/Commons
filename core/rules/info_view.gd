class_name InfoView
extends RefCounted
## What information upgrades add to the player's view (P4.9). Only the flags turned on
## are filled; with none, the player's view has no InfoView and matches a bot's.

## Flags, combined as bits in a definition's info parameter.
const OPPONENT_TYPES: int = 1
const CLOSEST_HAND: int = 2

var flags: int = 0
## For OPPONENT_TYPES: each opponent's remaining hand, as counts per Pattern.Type.
var opponent_types: Dictionary[int, PackedInt32Array] = {}
## For CLOSEST_HAND: the other seat with the fewest cards, and its cards by rank.
var closest_seat: int = Seats.NONE
var closest_counts: PackedByteArray = PackedByteArray()

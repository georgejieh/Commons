class_name DealResult
extends RefCounted
## The three seats' hands and the kitty after a deal.

var hands: Array[Hand] = []
var kitty: Array[CardInstance] = []
## How many cards of each rank the dealt deck held, counted once as it was dealt. It is
## what every seat counts unseen cards against (UnseenCards), so a bot knows the deck the
## table was dealt and nothing the run changes after.
var deck_counts: PackedByteArray = PackedByteArray()

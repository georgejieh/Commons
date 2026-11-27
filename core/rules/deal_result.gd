class_name DealResult
extends RefCounted
## The three seats' hands and the kitty after a deal.

## The three seats' hands, by seat. The landlord has not yet taken the kitty into theirs.
var hands: Array[Hand] = []
## The three cards left over, which the landlord takes.
var kitty: Array[CardInstance] = []
## How many cards of each rank the round holds, counted once as it was dealt, less any card
## a deal effect set aside face up. It is what every seat counts unseen cards against
## (UnseenCards), so a bot knows the deck the table was dealt and nothing the run changes
## after.
var deck_counts: PackedByteArray = PackedByteArray()
## Cards taken out of the round face up before the bid, in front of every seat (ADR 0043).
## No hand holds them, and the next deal deals them again.
var set_aside: Array[CardInstance] = []

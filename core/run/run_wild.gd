class_name RunWild
extends RefCounted
## Draws the round's wild ranks (ADR 0029). Mass Line draws one with every deal and Model
## Worker one when it is used, both on the deal stream: Mass Line after the deal, so the
## deal itself is unchanged. A drawn rank runs from 3 to 2, never one already wild and
## never one the deck holds no card of (ADR 0042), and at most two are wild at once. The
## ranks live in RunState.wild_ranks until the round ends. Both items are the player's,
## so the ranks are wild for the player's seat alone; a villager's card of one is a plain
## card (ADR 0039).

const MAX_RANKS: int = ReadingCodec.MAX_WILD_RANKS


## True while another rank may still be made wild this round.
static func has_room(state: RunState) -> bool:
	return state.wild_ranks.size() < MAX_RANKS


## Makes one more rank wild, drawn on stream from the ranks not wild yet, and returns it.
## The caller has checked there is room.
static func add(state: RunState, stream: RandomStream) -> int:
	var open: Array[int] = []
	var counts: PackedByteArray = state.deck.rank_counts()
	for rank: int in Ranks.TWO + 1:
		if not state.wild_ranks.has(rank) and counts[rank] > 0:
			open.append(rank)
	var drawn: int = open[stream.next_int(0, open.size() - 1)]
	state.wild_ranks.append(drawn)
	return drawn


## The event that tells the table a rank became wild, naming every rank wild now.
static func event(state: RunState, rank: int) -> RunEvent:
	var parts: PackedStringArray = []
	for wild: int in state.wild_ranks:
		parts.append(str(wild))
	return RunEvent.new(RunEvent.Type.WILD_RANKS, Seats.NONE, rank, 0.0, ",".join(parts))

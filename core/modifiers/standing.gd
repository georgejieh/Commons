class_name Standing
extends RefCounted
## A seat's standings: its rank order on a scale every seat shares, so plays of seats with
## different orders compare fairly (ADR 0039). A rank map is a seat's order as 0 to 14, and
## moving one rank there shifts the ranks between it and its target; across seats that
## would leave a promoted 3 level with another seat's 2 and every rank it passed a step
## weaker than another seat's. Standings start every rank STEP apart, so a rank moved just
## above another lands in the gap and nothing else moves. Within a seat both orders agree;
## only comparisons between seats, through a play's key, read standings.

## Room between two printed ranks: enough for every rank a Cadre may stand between them.
## The highest printed rank and the gap above it stay within a key's rank bits.
const STEP: int = 16
## Where the lowest printed rank stands: one STEP up, so there is a gap below it as well
## as above the highest. Turning standings over (ReversedRanks) puts a rank moved above
## the top in the gap below the bottom, and every value stays between 1 and 255.
const FLOOR: int = STEP
## Standings turn over about this: printed ranks land on printed ranks, and a value in a
## gap lands in the gap mirrored across the scale.
const TURN: int = FLOOR * 2 + (Ranks.COUNT - 1) * STEP


## Every rank in printed order, STEP apart.
static func identity() -> PackedByteArray:
	return of(Ranks.identity_map())


## The standings of a seat whose order no seat-only modifier changed: its map, scaled.
static func of(rank_map: PackedByteArray) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(rank_map.size())
	for rank: int in rank_map.size():
		result[rank] = FLOOR + rank_map[rank] * STEP
	return result

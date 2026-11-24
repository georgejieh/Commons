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
## Fifteen ranks times this stays below a key's rank bits.
const STEP: int = 16


## Every rank in printed order, STEP apart.
static func identity() -> PackedByteArray:
	return of(Ranks.identity_map())


## The standings of a seat whose order no seat-only modifier changed: its map, scaled.
static func of(rank_map: PackedByteArray) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(rank_map.size())
	for rank: int in rank_map.size():
		result[rank] = rank_map[rank] * STEP
	return result

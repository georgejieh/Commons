class_name CountKey
extends RefCounted
## Packs a 15-slot count vector into one integer, 4 bits per rank, for memoization.

## The bits one rank's count takes in a key.
const BITS_PER_RANK: int = 4
## The largest count a rank can hold in a key; a larger one spills into the next rank.
const MAX_COUNT: int = 15
## Masks one rank's count out of a key.
const RANK_MASK: int = 0xF


## Packs the counts into one integer, rank 0 in the lowest bits, to key a memo.
static func encode(counts: PackedByteArray) -> int:
	var key: int = 0
	for rank: int in Ranks.COUNT:
		key |= counts[rank] << (rank * BITS_PER_RANK)
	return key


## The counts a key stands for, as encode packed them. For tests.
static func decode(key: int) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for rank: int in Ranks.COUNT:
		counts[rank] = (key >> (rank * BITS_PER_RANK)) & RANK_MASK
	return counts

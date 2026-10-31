class_name CountKey
extends RefCounted
## Packs a 15-slot count vector into one integer, 4 bits per rank, for memoization.

const BITS_PER_RANK: int = 4
const MAX_COUNT: int = 15
const RANK_MASK: int = 0xF


static func encode(counts: PackedByteArray) -> int:
	var key: int = 0
	for rank: int in Ranks.COUNT:
		key |= counts[rank] << (rank * BITS_PER_RANK)
	return key


static func decode(key: int) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for rank: int in Ranks.COUNT:
		counts[rank] = (key >> (rank * BITS_PER_RANK)) & RANK_MASK
	return counts

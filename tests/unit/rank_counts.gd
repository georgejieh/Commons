class_name RankCounts
extends RefCounted
## Helpers for tests that work on count vectors.


static func describe(counts: PackedByteArray) -> String:
	var parts: PackedStringArray = []
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			parts.append("%sx%d" % [Ranks.label_key(rank), counts[rank]])
	return " ".join(parts)

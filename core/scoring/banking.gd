class_name Banking
extends RefCounted
## Splits the Commons pool by need. Shares are proportional, and the integer remainder
## goes one unit at a time to the neediest, with ties broken by seat order.

## Keeps every product below 2^63 for three seats.
const MAX_NEED: int = 1 << 28
## Pools saturate here, far above any value a player can read.
const MAX_POOL: int = 1 << 62


## Converts a score to pool units, rounding down. A negative score adds nothing.
static func to_pool_units(score: float) -> int:
	var clamped: float = Scorer.clamp_score(score)
	if clamped <= 0.0:
		return 0
	if clamped >= float(MAX_POOL):
		return MAX_POOL
	return floori(clamped)


## Pass honest needs after a caught lie, and the split recomputes. Declared needs clamp
## to 0..MAX_NEED. If nobody has a need, the pool is shared as if all needs were equal.
static func split(pool: int, needs: PackedInt64Array) -> PackedInt64Array:
	var weights: PackedInt64Array = PackedInt64Array()
	var total: int = 0
	for need: int in needs:
		var weight: int = clampi(need, 0, MAX_NEED)
		weights.append(weight)
		total += weight
	if total == 0:
		weights.fill(1)
		total = weights.size()

	var whole_part: int = 0
	var rest: int = 0
	@warning_ignore("integer_division")
	whole_part = pool / total
	rest = pool % total
	var shares: PackedInt64Array = PackedInt64Array()
	var handed_out: int = 0
	for weight: int in weights:
		@warning_ignore("integer_division")
		var share: int = whole_part * weight + rest * weight / total
		shares.append(share)
		handed_out += share
	var order: Array[int] = _neediest_first(weights)
	for index: int in pool - handed_out:
		shares[order[index % order.size()]] += 1
	return shares


static func _neediest_first(weights: PackedInt64Array) -> Array[int]:
	var order: Array[int] = []
	for index: int in weights.size():
		order.append(index)
	var by_need: Callable = func(first: int, second: int) -> bool:
		if weights[first] != weights[second]:
			return weights[first] > weights[second]
		return first < second
	order.sort_custom(by_need)
	return order

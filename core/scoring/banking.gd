class_name Banking
extends RefCounted
## Splits the Commons pool by need. Shares are proportional, and the integer remainder
## goes one unit at a time to the neediest, with ties broken by seat order.


## Pass honest needs after a caught lie, and the split recomputes. If nobody declares a
## need, the pool is shared as if everyone's need were equal.
static func split(pool: int, needs: PackedInt32Array) -> PackedInt32Array:
	var weights: PackedInt32Array = needs.duplicate()
	var total: int = 0
	for need: int in needs:
		total += need
	if total == 0:
		weights.fill(1)
		total = weights.size()

	var shares: PackedInt32Array = PackedInt32Array()
	var handed_out: int = 0
	for weight: int in weights:
		@warning_ignore("integer_division")
		var share: int = pool * weight / total
		shares.append(share)
		handed_out += share
	var order: Array[int] = _neediest_first(weights)
	for index: int in pool - handed_out:
		shares[order[index % order.size()]] += 1
	return shares


static func _neediest_first(weights: PackedInt32Array) -> Array[int]:
	var order: Array[int] = []
	for index: int in weights.size():
		order.append(index)
	var by_need: Callable = func(first: int, second: int) -> bool:
		if weights[first] != weights[second]:
			return weights[first] > weights[second]
		return first < second
	order.sort_custom(by_need)
	return order

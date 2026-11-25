class_name ToolStats
extends RefCounted
## The two percentiles the tools read, named for how they read one. A budget or a time
## reported as "p99" takes a value that was measured (nearest_rank): a threshold is judged
## against a real decision or frame, never against a value between two. A report of how a
## population spreads, as the balance harness's curves are, reads between the two nearest
## (interpolated), so a small sample still moves smoothly. Development only; tools/ never
## ships.


## The value percent of the way through sorted values, by nearest rank: the element at
## size * percent / 100, or the last. 0 when there are none.
static func nearest_rank(sorted: PackedFloat64Array, percent: int) -> float:
	if sorted.is_empty():
		return 0.0
	@warning_ignore("integer_division")
	return sorted[mini(sorted.size() - 1, sorted.size() * percent / 100)]


## The value at fraction (0 to 1) of sorted values, read between the two nearest. 0 when
## there are none.
static func interpolated(sorted: PackedFloat64Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	var at: float = fraction * (sorted.size() - 1)
	var below: int = floori(at)
	var above: int = mini(below + 1, sorted.size() - 1)
	return lerpf(sorted[below], sorted[above], at - below)


## A sorted copy of values.
static func sorted_of(values: PackedFloat64Array) -> PackedFloat64Array:
	var copy: PackedFloat64Array = values.duplicate()
	copy.sort()
	return copy

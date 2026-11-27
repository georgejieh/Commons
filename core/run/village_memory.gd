class_name VillageMemory
extends RefCounted
## What each family remembers of the player, across runs (P4.6): how often the player
## fed, bombed, denounced and betrayed them, built from Set summaries. Counts fade by a
## data rate at each new run, so old harm weighs less than new harm but lingers.

## Family ID to counts indexed by SetSummary.Kind.
var counts: Dictionary[String, PackedFloat64Array] = {}


static func from_dict(data: Dictionary) -> VillageMemory:
	var memory: VillageMemory = VillageMemory.new()
	for family_id: String in data:
		var row: PackedFloat64Array = []
		for value: Variant in data[family_id]:
			row.append(RunState.float_from_text(str(value)))
		memory.counts[family_id] = row
	return memory


func to_dict() -> Dictionary:
	var saved: Dictionary[String, Array] = {}
	for family_id: String in counts:
		var row: Array[String] = []
		for value: float in counts[family_id]:
			row.append(RunState.float_text(value))
		saved[family_id] = row
	return saved


## Adds what one Set left behind.
func record(summary: SetSummary) -> void:
	for family_id: String in summary.counts:
		if not counts.has(family_id):
			var row: PackedFloat64Array = []
			row.resize(SetSummary.KIND_COUNT)
			counts[family_id] = row
		for kind: int in SetSummary.KIND_COUNT:
			counts[family_id][kind] += summary.counts[family_id][kind]


func count(family_id: String, kind: SetSummary.Kind) -> float:
	if not counts.has(family_id):
		return 0.0
	return counts[family_id][kind]


## A copy for a new run: every count scaled by the share kept per run.
func carried(params: MemoryParams) -> VillageMemory:
	var next: VillageMemory = VillageMemory.new()
	for family_id: String in counts:
		var row: PackedFloat64Array = counts[family_id].duplicate()
		for kind: int in row.size():
			row[kind] *= params.kept_per_run
		next.counts[family_id] = row
	return next


## The family's grudge score: each count times its kind's weight.
func grudge(family_id: String, params: MemoryParams) -> float:
	var score: float = 0.0
	for kind: int in SetSummary.KIND_COUNT:
		score += count(family_id, kind as SetSummary.Kind) * params.weight(kind)
	return score


## How strongly the family holds the player in mind at the table, from 0 to 1.
func pull(family_id: String, params: MemoryParams) -> float:
	return clampf(grudge(family_id, params) / params.full_grudge, 0.0, 1.0)

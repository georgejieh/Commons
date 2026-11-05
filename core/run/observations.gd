class_name Observations
extends RefCounted
## What the player has seen each villager do at the table this run, per family: the
## dossier's source (P3B.8). It holds only what happened in view, never a personality.

enum Kind { BIDS, CALLS, BOMBS, PASSES, BEAT_TEAMMATE, WENT_OUT, LANDLORD_ROUNDS }

const KIND_COUNT: int = 7

## Family ID to counts indexed by Kind.
var counts: Dictionary[String, PackedInt64Array] = {}


static func from_dict(data: Dictionary) -> Observations:
	var observations: Observations = Observations.new()
	for family_id: String in data:
		var row: PackedInt64Array = []
		row.resize(KIND_COUNT)
		var saved: Array = data[family_id]
		for index: int in mini(saved.size(), KIND_COUNT):
			row[index] = int(saved[index])
		observations.counts[family_id] = row
	return observations


func add(family_id: String, kind: Kind, amount: int = 1) -> void:
	if not counts.has(family_id):
		var row: PackedInt64Array = []
		row.resize(KIND_COUNT)
		counts[family_id] = row
	counts[family_id][kind] += amount


func count(family_id: String, kind: Kind) -> int:
	if not counts.has(family_id):
		return 0
	return counts[family_id][kind]


func has_family(family_id: String) -> bool:
	return counts.has(family_id)


func to_dict() -> Dictionary:
	var saved: Dictionary[String, Array] = {}
	for family_id: String in counts:
		saved[family_id] = Array(counts[family_id])
	return saved

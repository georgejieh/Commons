class_name SetSummary
extends RefCounted
## What one Set left behind: per villager, how often they were fed, bombed, denounced
## and betrayed. Memory, epilogues and the New Landlord read these, never raw logs.

enum Kind { FED, BOMBED, DENOUNCED, BETRAYED }

const KIND_COUNT: int = 4

var set_number: int
## Family ID to counts indexed by Kind.
var counts: Dictionary[String, PackedInt64Array] = {}


func _init(number: int) -> void:
	set_number = number


static func from_dict(data: Dictionary) -> SetSummary:
	var summary: SetSummary = SetSummary.new(int(data["set_number"]))
	var saved: Dictionary = data["counts"]
	for family_id: String in saved:
		var row: PackedInt64Array = []
		for value: Variant in saved[family_id]:
			row.append(int(value))
		summary.counts[family_id] = row
	return summary


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


func to_dict() -> Dictionary:
	var saved: Dictionary[String, Array] = {}
	for family_id: String in counts:
		saved[family_id] = Array(counts[family_id])
	return {"set_number": set_number, "counts": saved}

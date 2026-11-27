class_name SetSummary
extends RefCounted
## What one Set left behind: per villager, how often they were fed, bombed, denounced
## and betrayed. Memory, epilogues and the New Landlord read these, never raw logs.

## What the player did to a family, or it to them: fed, bombed, denounced or betrayed.
enum Kind { FED, BOMBED, DENOUNCED, BETRAYED }

## The Set's number across the run, from 0.
var set_number: int
## Family ID to counts indexed by Kind.
var counts: Dictionary[String, PackedInt64Array] = {}


func _init(number: int) -> void:
	set_number = number


## Rebuilds a summary from the run save.
static func from_dict(data: Dictionary) -> SetSummary:
	var summary: SetSummary = SetSummary.new(int(data["set_number"]))
	var saved: Dictionary = data["counts"]
	for family_id: String in saved:
		var row: PackedInt64Array = []
		for value: Variant in saved[family_id]:
			row.append(int(value))
		summary.counts[family_id] = row
	return summary


## Adds amount to a family's count of kind, making its row the first time.
func add(family_id: String, kind: Kind, amount: int = 1) -> void:
	if not counts.has(family_id):
		var row: PackedInt64Array = []
		row.resize(Kind.size())
		counts[family_id] = row
	counts[family_id][kind] += amount


## A family's count of kind; 0 for a family with none.
func count(family_id: String, kind: Kind) -> int:
	if not counts.has(family_id):
		return 0
	return counts[family_id][kind]


## The summary as a map for the run save.
func to_dict() -> Dictionary:
	var saved: Dictionary[String, Array] = {}
	for family_id: String in counts:
		saved[family_id] = Array(counts[family_id])
	return {"set_number": set_number, "counts": saved}

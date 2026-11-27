class_name EpilogueLine
extends RefCounted
## One line of a run's epilogue (ADR 0024): the families it names, its string key, and
## their surname keys. Families that would get the same line share it, in roster order.
## The dead families' line belongs to no family and names all the dead.

## The families' roster IDs in roster order, or none for the line naming the dead.
var family_ids: Array[String] = []
## The string key of the line's text.
var key: String
## The named families' surname keys in roster order: for {name}, or on the dead line
## for {names}.
var name_keys: Array[String] = []


func _init(line_key: String) -> void:
	key = line_key


## Names one more family on the line.
func add(family_id: String, surname_key: String) -> void:
	family_ids.append(family_id)
	name_keys.append(surname_key)

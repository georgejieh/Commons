class_name EpilogueLine
extends RefCounted
## One line of a run's epilogue (ADR 0024): the family it is about, its string key, and
## the surname keys that fill it. The dead families' line belongs to no one family and
## names all of them.

## The family's roster ID, or empty for the line naming the dead.
var family_id: String
var key: String
## The family's surname key, for {name}.
var name_key: String
## Every dead family's surname key, in roster order, for {names}.
var name_keys: Array[String] = []


func _init(family: String, line_key: String, surname_key: String) -> void:
	family_id = family
	key = line_key
	name_key = surname_key

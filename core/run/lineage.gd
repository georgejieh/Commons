class_name Lineage
extends RefCounted
## What one finished run leaves the next (ADR 0025, "Lineage"): its kind, one of
## RunLineage's (NONE, HEIRLOOM, LOYAL, LABEL), and the values that kind reads, as the
## profile keeps them.

## Which lineage it is: RunLineage.NONE for none.
var kind: String = RunLineage.NONE
## What the kind reads: an heirloom's rank and suit, or the loyal families.
var values: Dictionary = {}


func _init(lineage_kind: String = RunLineage.NONE, lineage_values: Dictionary = {}) -> void:
	kind = lineage_kind
	values = lineage_values

class_name StringTable
extends Node
## The Strings autoload: resolves string-table keys for presentation (ADR 0006).
## core/ holds keys only; everything a player reads comes through here.


func text(key: String) -> String:
	return tr(key)


## The key's text with its {name} placeholders filled from values.
func format(key: String, values: Dictionary) -> String:
	return tr(key).format(values)


func has(key: String) -> bool:
	return tr(key) != key

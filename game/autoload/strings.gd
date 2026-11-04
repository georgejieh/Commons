class_name StringTable
extends Node
## The Strings autoload: resolves string-table keys for presentation (ADR 0006).
## core/ holds keys only; everything a player reads comes through here.


func text(key: String) -> String:
	return tr(key)


## The key's text with its {name} placeholders filled from values.
func format(key: String, values: Dictionary) -> String:
	return tr(key).format(values)


## A count line: the key's ".one" form when there is exactly one and the table has it.
func count(key: String, amount: int) -> String:
	var chosen: String = key + ".one" if amount == 1 and has(key + ".one") else key
	return tr(chosen).format({"count": amount})


func has(key: String) -> bool:
	return tr(key) != key


## A score in short-scale form, with suffixes from the table.
func score(value: float) -> String:
	var suffixes: PackedStringArray = []
	for key: String in ScoreFormat.SUFFIX_KEYS:
		suffixes.append(tr(key))
	return ScoreFormat.short(value, suffixes)

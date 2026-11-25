class_name StringTable
extends Node
## The Strings autoload: the string table's (ADR 0006) count lines and score figures,
## the text that needs more than tr(). Nodes look a key up with tr() and static builders
## with TranslationServer.translate; core/ holds keys only.


## A count line: the key's ".one" form when there is exactly one and the table has it.
func count(key: String, amount: int) -> String:
	var chosen: String = key + ".one" if amount == 1 and _has(key + ".one") else key
	return tr(chosen).format({"count": amount})


## A score in short-scale form, with suffixes from the table.
func score(value: float) -> String:
	return ScoreFormat.short(value, _suffixes())


## A Rate or Zeal: one decimal when it is not whole.
func factor(value: float) -> String:
	return ScoreFormat.factor(value, _suffixes())


func _has(key: String) -> bool:
	return tr(key) != key


func _suffixes() -> PackedStringArray:
	var suffixes: PackedStringArray = []
	for key: String in ScoreFormat.SUFFIX_KEYS:
		suffixes.append(tr(key))
	return suffixes

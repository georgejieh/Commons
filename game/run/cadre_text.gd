class_name CadreText
extends RefCounted
## Turns a modifier's numbers into what its texts print (ADR 0021): a rank as its label,
## a decimal as a decimal. A value is a rank when its name is "rank", starts with
## "rank" or ends with "_rank".


## The modifier's rules with its parameters filled in.
static func rules(definition: ModifierDef) -> String:
	var text: String = TranslationServer.translate(definition.text_key)
	return text.format(words(definition.text_values()))


## The values with every rank written as its label and every decimal as text.
static func words(values: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var written: Dictionary[String, Variant] = {}
	for key: String in values:
		var value: Variant = values[key]
		if is_rank(key) and value is int and Ranks.is_valid(value):
			written[key] = TranslationServer.translate(Ranks.label_key(value))
		elif value is float:
			written[key] = String.num(value)
		else:
			written[key] = value
	return written


static func is_rank(key: String) -> bool:
	return key.begins_with("rank") or key.ends_with("_rank")

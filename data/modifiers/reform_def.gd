class_name ReformDef
extends Resource
## One Reform (ADR 0021): a permanent upgrade for the rest of the run, bought at the state
## store. Its behaviour is a small effect script registered by ID in ReformRegistry, and
## every number it uses is in parameters.

@export var id: String
@export var cost: int
## Finished runs needed before it is offered; RunUnlocks reads it (ADR 0025).
@export var unlock_tier: int = 0
@export var parameters: Dictionary[String, int]
@export var name_key: String
@export var text_key: String


## The values that fill the rules text: the parameters, with Zeal in hundredths written as
## a multiple, as ModifierDef writes it.
func text_values() -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	for key: String in parameters:
		if key.begins_with(ModifierDef.ZEAL_PERCENT_PREFIX):
			values[key] = ModifierDef.multiple(parameters[key] / ModifierDef.PERCENT)
		else:
			values[key] = parameters[key]
	return values

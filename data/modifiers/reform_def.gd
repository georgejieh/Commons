class_name ReformDef
extends Resource
## One Reform (ADR 0021): a permanent upgrade for the rest of the run, bought at the state
## store. Its behaviour is a small effect script registered by ID in ReformRegistry, and
## every number it uses is in parameters.

@export var id: String
@export var cost: int
## Finished runs needed before it is offered (P4.14). Nothing reads it yet.
@export var unlock_tier: int = 0
@export var parameters: Dictionary[String, int]
## Kept out of the state store's draw while set. Supply Cooperative waits here until
## envelopes exist (P4.11g), since its rule is about them.
@export var held_back: bool = false
@export var name_key: String
@export var text_key: String


## The values that fill the rules text: the parameters.
func text_values() -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	for key: String in parameters:
		values[key] = parameters[key]
	return values

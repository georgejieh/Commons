class_name ReformDef
extends Resource
## One Reform (ADR 0021): a permanent upgrade for the rest of the run, bought at the state
## store. Its behaviour is a small effect script registered by ID in ReformRegistry, and
## every number it uses is in parameters.

## The ID the registries, the saves and the pools name it by.
@export var id: String
## What it costs at the counter, in coupons.
@export var cost: int
## Finished runs needed before it is offered; RunUnlocks reads it (ADR 0025).
@export var unlock_tier: int = 0
## The numbers its effect script reads, by name.
@export var parameters: Dictionary[String, int]
## The string key of its name.
@export var name_key: String
## The string key of its rules text.
@export var text_key: String


## The values that fill the rules text: the parameters, with Zeal in hundredths written as
## a multiple, as ModifierDef writes it.
func text_values() -> Dictionary[String, Variant]:
	return ModifierDef.text_numbers(parameters, [ModifierDef.ZEAL_PERCENT_PREFIX])

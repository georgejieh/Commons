class_name DirectiveDef
extends Resource
## One Directive (ADR 0021): bought at the state store, it raises every hand type in its
## family by one level at once, for the rest of the run.

## The ID the registries, the saves and the pools name it by.
@export var id: String
## Pattern.Type values. Data does not name core enums, so the numbers stand for them.
@export var hand_types: Array[int]
## What it costs at the counter, in coupons.
@export var cost: int
## Finished runs needed before it is offered; RunUnlocks reads it (ADR 0025).
@export var unlock_tier: int = 0
## The string key of its name.
@export var name_key: String
## The string key of its rules text.
@export var text_key: String

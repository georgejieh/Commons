class_name AuditParams
extends Resource
## How often declared needs are checked before a Commons split (P4.3). The audit hook
## can raise the chance further, as the Work-Point Audit debuff does.

## Chance, from 0 to 1, that each declaration is checked.
@export var base_chance: float = 0.15
## Added while a family in informer_families is in the village.
@export var informer_chance: float = 0.2
@export var informer_families: Array[String] = ["zhou"]

class_name MemoryParams
extends Resource
## How villagers remember the player (P4.6): what each kind of event weighs toward a
## family's grudge, how much survives each new run, and the grudge that counts as full.

## Being fed softens a grudge, so its weight is negative.
@export var fed_weight: float = -1.0
@export var bombed_weight: float = 2.0
@export var denounced_weight: float = 4.0
@export var betrayed_weight: float = 1.0
## The share of every count kept when a new run begins.
@export var kept_per_run: float = 0.5
## A grudge score at or above this pulls a bot's memory of the player to 1.
@export var full_grudge: float = 10.0


func weight(kind: SetSummary.Kind) -> float:
	match kind:
		SetSummary.Kind.FED:
			return fed_weight
		SetSummary.Kind.BOMBED:
			return bombed_weight
		SetSummary.Kind.DENOUNCED:
			return denounced_weight
	return betrayed_weight

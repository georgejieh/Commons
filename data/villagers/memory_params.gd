class_name MemoryParams
extends Resource
## How villagers remember the player: what each kind of event weighs toward a
## family's grudge, how much survives each new run, and the grudge that counts as full.

## What each time a family's villager was fed adds to its grudge: negative, since being
## fed softens it.
@export var fed_weight: float = -1.0
## What each time a family's villager was bombed adds to its grudge.
@export var bombed_weight: float = 2.0
## What each time a family's villager was denounced adds to its grudge.
@export var denounced_weight: float = 4.0
## What each time a family's villager was betrayed adds to its grudge.
@export var betrayed_weight: float = 1.0
## The share of every count kept when a new run begins.
@export var kept_per_run: float = 0.5
## A grudge score at or above this pulls a bot's memory of the player to 1.
@export var full_grudge: float = 10.0
## How far a fully warm family's cooperation rises as the player's teammate (ADR 0025).
@export var loyal_cooperation: float = 0.3


## What a Set summary of this kind adds to a family's grudge.
func weight(kind: SetSummary.Kind) -> float:
	match kind:
		SetSummary.Kind.FED:
			return fed_weight
		SetSummary.Kind.BOMBED:
			return bombed_weight
		SetSummary.Kind.DENOUNCED:
			return denounced_weight
	return betrayed_weight

class_name LineageParams
extends Resource
## What the last finished run leaves the next one (ADR 0025, "Lineage"). Ranks are Ranks
## values (data does not name core types): 8 is J and 11 is A.

## The heirloom's rank range, both ends included.
@export var heirloom_low_rank: int = 8
@export var heirloom_high_rank: int = 11
## Denunciation a run inherits with the label.
@export var label_denunciation: int = 15
## A loyal family's memory in the next run: this many feedings and nothing else.
@export var loyal_feedings: float = 4.0
## Loyal families a peasant ending leaves, and The Commons.
@export var social_families: int = 1
@export var commons_families: int = 2

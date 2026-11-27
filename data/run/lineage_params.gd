class_name LineageParams
extends Resource
## What the last finished run leaves the next one (ADR 0025, "Lineage"). Ranks are Ranks
## values, which are numbered constants and not an enum: 8 is J and 11 is A.

## The lowest rank an heirloom can have, as a Ranks value.
@export var heirloom_low_rank: int = 8
## The highest rank an heirloom can have, as a Ranks value.
@export var heirloom_high_rank: int = 11
## Denunciation a run inherits with the label.
@export var label_denunciation: int = 15
## A loyal family's memory in the next run: this many feedings and nothing else.
@export var loyal_feedings: float = 4.0
## Loyal families a peasant ending leaves.
@export var social_families: int = 1
## Loyal families The Commons ending leaves.
@export var commons_families: int = 2

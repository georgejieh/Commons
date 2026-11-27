class_name ResentmentParams
extends Resource
## What breeds Resentment, and what it costs (P4.2). Resentment runs from 0 to max.

@export var max: int = 100
@export var private_purchase: int = 5
## Added at each Set's end for every private Cadre the player holds.
@export var private_cadre: int = 2
## Added for each card the player scores that carries their own stamp.
@export var stamped_card: int = 1
## Added when the player grabs the landlord seat from a villager who held it.
@export var grab: int = 4
## Denunciation added at each Set's end, sampled at Resentment as a share of max. This
## is the one mapping from Resentment to Denunciation.
@export var denunciation: Curve
## How much a bot holds against the player at full Resentment, before its grudge scales it.
@export var grudge_at_max: float = 1.0

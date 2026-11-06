class_name BossPool
extends Resource
## Who runs the boss Sets (P4.7): authored officials with rule twists, the twist a risen
## villager brings, the final New Landlord, and how closely the New Landlord copies you.

@export var officials: Array[ModifierDef] = []
## A villager who held the landlord seat for a whole Set: seated, and landlord from the
## first round.
@export var risen: ModifierDef
@export var new_landlord: ModifierDef
## Sets of the player's play the New Landlord copies.
@export var style_sets: int = 3
## Bonus toward a hand type the player always played, scaled by its share.
@export var style_bias: float = 2.0
## Ambition at a bid rate of 1; a rate of 0 gives the negative, one half gives none.
@export var ambition_span: float = 4.0


func all() -> Array[ModifierDef]:
	var found: Array[ModifierDef] = officials.duplicate()
	found.append(risen)
	found.append(new_landlord)
	return found

class_name FreeRideParams
extends Resource
## How the player's teammate slacks as the player takes more of the Commons (P4.4).
## Below fair_share the teammate gives full effort; at full_share its effort has fallen
## to its own cooperation, so a cooperative teammate barely slacks and a selfish one
## slacks often.

@export var fair_share: float = 0.5
@export var full_share: float = 1.0

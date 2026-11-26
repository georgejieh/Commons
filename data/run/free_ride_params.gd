class_name FreeRideParams
extends Resource
## How the player's teammate slacks as the player takes more of the Commons.
## Below fair_share the teammate gives full effort; at full_share its effort has fallen
## to its own cooperation, so a cooperative teammate barely slacks and a selfish one
## slacks often.

## The share of the Commons, from 0 to 1, below which the teammate gives full effort.
@export var fair_share: float = 0.5
## The share of the Commons, from 0 to 1, at which the teammate's effort has fallen to
## its cooperation.
@export var full_share: float = 1.0

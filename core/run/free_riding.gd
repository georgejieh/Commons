class_name FreeRiding
extends RefCounted
## The teammate's effort from the player's share of everything the Commons has paid
## peasants this run (P4.4).


## The player's share, from 0 to 1. Nothing paid yet counts as no share.
static func share(state: RunState) -> float:
	if state.commons_paid <= 0:
		return 0.0
	return float(state.commons_received) / state.commons_paid


## Full effort up to the fair share, falling to the teammate's cooperation at the full one.
static func effort(player_share: float, cooperation: float, params: FreeRideParams) -> float:
	var span: float = params.full_share - params.fair_share
	var weight: float = clampf((player_share - params.fair_share) / span, 0.0, 1.0)
	return lerpf(1.0, minf(cooperation, 1.0), weight)

class_name MassLineEffect
extends ReformEffect
## Mass Line (ADR 0029): every round, ranks drawn with the deal are wild for the player's
## seat alone (ADR 0039).
## RunLoop draws them on the deal stream after the deal, so the deal is unchanged and the
## rank is known before anyone bids.

## Parameter key: how many ranks are drawn wild each round.
const RANKS: String = "ranks"


## Needs the number of ranks.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANKS])


## The ranks drawn wild each round, from the parameter.
func wild_ranks_per_round() -> int:
	return parameters[RANKS]

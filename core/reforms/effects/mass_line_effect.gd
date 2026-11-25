class_name MassLineEffect
extends ReformEffect
## Mass Line (ADR 0029): every round, ranks drawn with the deal are wild for the player's
## seat alone (ADR 0039).
## RunLoop draws them on the deal stream after the deal, so the deal is unchanged and the
## rank is known before anyone bids.

const RANKS: String = "ranks"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANKS])


func wild_ranks_per_round() -> int:
	return parameters[RANKS]

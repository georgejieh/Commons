class_name PlotSeizedEffect
extends ModifierEffect
## No plot swap while it is in force, and plot cards drawn at random are destroyed for
## the run when it first comes into force. With an empty plot only the swap is lost
## (ADR 0023).

const SWAPS: String = "swaps"
const CARDS: String = "cards"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([SWAPS, CARDS])


func round_start(context: RoundContext) -> void:
	context.cap_swaps(parameters[SWAPS])
	if context.arrived == self:
		context.seize_plot += parameters[CARDS]

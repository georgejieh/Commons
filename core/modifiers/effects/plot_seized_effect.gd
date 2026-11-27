class_name PlotSeizedEffect
extends ModifierEffect
## No plot swap while it is in force, and plot cards drawn at random are destroyed for
## the run when it first comes into force. With an empty plot only the swap is lost
## (ADR 0023).

## Parameter key: the most plot swaps the round allows.
const SWAPS: String = "swaps"
## Parameter key: how many plot cards are destroyed when it first comes into force.
const CARDS: String = "cards"


## Needs the swap cap and the cards destroyed.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([SWAPS, CARDS])


## Caps the round's plot swaps, and destroys the plot cards the round it arrives.
func round_start(context: RoundContext) -> void:
	context.cap_swaps(parameters[SWAPS])
	if context.arrived == self:
		context.seize_plot += parameters[CARDS]

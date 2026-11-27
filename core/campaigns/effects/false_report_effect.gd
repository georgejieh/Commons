class_name FalseReportEffect
extends CampaignEffect
## On the player's turn: this Quota's progress rises by a share of its target, the norm
## rises by steps for every later Quota, and Resentment rises (ADR 0032). The steps are
## held in reported_steps until the next Quota starts, so this Quota's own target stays
## as it was, as with the steps a Quota earns by beating its target.

const PERCENT: String = "percent"
const STEPS: String = "steps"
const RESENTMENT: String = "resentment"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([PERCENT, STEPS, RESENTMENT])


func apply(context: CampaignContext) -> void:
	var reported: float = context.target * parameters[PERCENT] / 100.0
	context.state.set_progress += reported
	context.state.norm_steps += parameters[STEPS]
	context.state.reported_steps += parameters[STEPS]
	context.resent(parameters[RESENTMENT])

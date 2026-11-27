class_name FalseReportEffect
extends CampaignEffect
## On the player's turn: this Quota's progress rises by a share of its target, the norm
## rises by steps for every later Quota, and Resentment rises (ADR 0032). The steps are
## held in reported_steps until the next Quota starts, so this Quota's own target stays
## as it was, as with the steps a Quota earns by beating its target.

## Parameter key: the share of the Quota's target added to its progress, in percent.
const PERCENT: String = "percent"
## Parameter key: the steps the norm rises by for every later Quota.
const STEPS: String = "steps"
## Parameter key: the Resentment the report costs.
const RESENTMENT: String = "resentment"


## Needs the progress share, the norm steps and the Resentment.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([PERCENT, STEPS, RESENTMENT])


## Adds the reported progress, raises the norm and holds the steps in reported_steps.
func apply(context: CampaignContext) -> void:
	var reported: float = ModifierEffect.fraction(context.target * parameters[PERCENT])
	context.state.set_progress += reported
	context.state.norm_steps += parameters[STEPS]
	context.state.reported_steps += parameters[STEPS]
	context.resent(parameters[RESENTMENT])

class_name GrainLoanEffect
extends CampaignEffect
## Coupons now, Famine for them: the rise goes through the meter path, so its setback
## and the death check apply as for any other rise.

## Parameter key: the Coupons the loan gives.
const COUPONS: String = "coupons"
## Parameter key: the Famine the loan costs.
const FAMINE: String = "famine"


## Needs the Coupons and the Famine.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS, FAMINE])


## Gives the Coupons, logs them and raises Famine through the meter path.
func apply(context: CampaignContext) -> void:
	context.state.coupons += parameters[COUPONS]
	context.add_event(
		RunEvent.new(RunEvent.Type.COUPONS_GAINED, context.player, parameters[COUPONS])
	)
	context.move_meter(CampaignContext.FAMINE_SOURCE, parameters[FAMINE])

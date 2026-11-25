class_name GrainLoanEffect
extends CampaignEffect
## Coupons now, Famine for them: the rise goes through the meter path, so its setback
## and the death check apply as for any other rise.

const COUPONS: String = "coupons"
const FAMINE: String = "famine"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([COUPONS, FAMINE])


func apply(context: CampaignContext) -> void:
	context.state.coupons += parameters[COUPONS]
	context.add_event(
		RunEvent.new(RunEvent.Type.COUPONS_GAINED, context.player, parameters[COUPONS])
	)
	context.move_meter(CampaignContext.FAMINE_SOURCE, parameters[FAMINE])

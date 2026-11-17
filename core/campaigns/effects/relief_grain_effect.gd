class_name ReliefGrainEffect
extends CampaignEffect
## Famine falls, through the meters' one path down: never below 0, and a fall back below
## a band re-arms its setback (ADR 0032). It mirrors Grain Loan, on the same meter row.

const FAMINE: String = "famine"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([FAMINE])


func apply(context: CampaignContext) -> void:
	context.move_meter(CampaignContext.FAMINE_SOURCE, -parameters[FAMINE])

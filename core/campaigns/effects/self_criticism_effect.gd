class_name SelfCriticismEffect
extends CampaignEffect
## Resentment falls, through its one path down, and Denunciation rises for it through the
## meter path, so its setback and the death check apply as for any other rise (ADR 0032).

const RESENTMENT: String = "resentment"
const DENUNCIATION: String = "denunciation"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RESENTMENT, DENUNCIATION])


func apply(context: CampaignContext) -> void:
	context.relent(parameters[RESENTMENT])
	context.move_meter(CampaignContext.DENUNCIATION_SOURCE, parameters[DENUNCIATION])

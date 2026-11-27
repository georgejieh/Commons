class_name SelfCriticismEffect
extends CampaignEffect
## Resentment falls, through its one path down, and Denunciation rises for it through the
## meter path, so its setback and the death check apply as for any other rise (ADR 0032).

## Parameter key: the Resentment that falls.
const RESENTMENT: String = "resentment"
## Parameter key: the Denunciation that rises.
const DENUNCIATION: String = "denunciation"


## Needs the Resentment it lowers and the Denunciation it raises.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RESENTMENT, DENUNCIATION])


## Lowers Resentment and raises Denunciation through the meter path.
func apply(context: CampaignContext) -> void:
	context.relent(parameters[RESENTMENT])
	context.move_meter(CampaignContext.DENUNCIATION_SOURCE, parameters[DENUNCIATION])

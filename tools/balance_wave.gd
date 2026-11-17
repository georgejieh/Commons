class_name BalanceWave
extends RefCounted
## What the harness knows of ADR 0032's second wave: the pieces whose purchases and uses
## it counts, and when its two collective Campaigns help. Its strategies buy the wave's
## pieces by the rules they buy everything by.

## The sixteen Cadres and three Campaigns.
const ITEMS: Array[String] = [
	"night_school",
	"iron_and_coal",
	"advanced_cooperative",
	"double_share_plough",
	"open_accounts",
	"tractor_station",
	"the_gleaners",
	"public_granary",
	"five_year_plan",
	"back_door",
	"informers_reward",
	"forged_seal",
	"loudspeaker",
	"rent_book",
	"grain_speculator",
	"prize_exhibit",
	"self_criticism",
	"relief_grain",
	"false_report",
]
const RELIEF_GRAIN: String = "relief_grain"
const SELF_CRITICISM: String = "self_criticism"


## False for a Campaign that lowers a meter before there is enough to lower: Relief Grain
## below its Famine, and Self-Criticism below its Resentment or when its Denunciation
## would end the run. Every other Campaign helps whenever its rule allows.
static func helps(campaign_id: String, state: RunState, params: BalanceParams) -> bool:
	match campaign_id:
		RELIEF_GRAIN:
			return state.famine >= params.relief_famine_at
		SELF_CRITICISM:
			var rise: int = _campaign(campaign_id).parameters[SelfCriticismEffect.DENUNCIATION]
			var safe: bool = state.denunciation + rise < RunLoop.DEFAULT_METERS.denunciation.death
			return safe and state.resentment >= params.criticism_resentment_at
	return true


static func _campaign(campaign_id: String) -> CampaignDef:
	for definition: CampaignDef in RunCampaigns.all():
		if definition.id == campaign_id:
			return definition
	return null

class_name RunFigures
extends RefCounted
## The run's numbers as its rules and data set them, for screens to show: the Quota's
## reward and target, the norm, slots, what each risk costs, the audit's chance and the
## hand levels. RunController builds it over each run it attaches, as
## controller.figures.

var _loop: RunLoop


func _init(loop: RunLoop) -> void:
	_loop = loop


## The current Set's target in force, as RunLoop.target() works it out.
func target() -> float:
	return _loop.target()


## The most rounds a Set of this run plays.
func max_rounds() -> int:
	return _loop.sets().max_rounds()


## Coupons the current Set pays when its Quota is met, a Reform's extra included.
func quota_reward() -> int:
	return _loop.sets().reward(_loop.state.set_type) + RunReforms.quota_coupons(_loop.state)


## Overfulfilment steps the Set just finished earned, 0 while a Set is in play.
func over_steps() -> int:
	return _loop.state.over_steps


## The extra coupons those steps paid, on top of quota_reward().
func over_bonus() -> int:
	return _loop.sets().over_bonus(_loop.state.over_steps)


## How far the norm has raised targets this run, in percent of each base target. After a
## Set ends, it already counts that Set's steps, which raise the Quotas to come.
func norm_percent() -> int:
	return _loop.sets().norm_percent(_loop.state.norm_steps)


## How far one step raises the norm, in percent.
func norm_step_percent() -> int:
	return _loop.sets().norm_percent(1)


## How far the Set just finished raised the norm, in percent.
func norm_added_percent() -> int:
	return _loop.sets().norm_percent(_loop.state.over_steps)


## True while high Famine cuts the store's slots.
func is_rationed() -> bool:
	return _loop.state.rationed


## The Famine value rationing must fall below to lift.
func rationing_lifts_below() -> int:
	var bands: MeterBands = RunDefaults.METERS.famine
	return bands.mid - bands.rearm_margin


## Cadres the player can hold at once, Reforms included.
func cadre_slots() -> int:
	return RunReforms.cadre_slots(_loop.state)


## How many Campaigns the player can hold at once, Reforms included.
func campaign_slots() -> int:
	return RunReforms.campaign_slots(_loop.state)


## What every villager declares by default, a fair need to start the player's choice.
func base_need() -> int:
	return RunDefaults.PARAMS.base_need


## The Resentment the player's grab of a held landlord seat adds.
func grab_cost() -> int:
	return RunDefaults.RESENTMENT.grab


## The Resentment every black market purchase adds.
func purchase_resentment() -> int:
	return RunDefaults.RESENTMENT.private_purchase


## The Denunciation a lie about need costs when an audit catches it.
func lie_cost() -> int:
	return RunDefaults.METERS.source(RunMeters.CAUGHT_LIE).amount


## The chance, 0 to 1, that each claim on the Commons is audited this round.
func audit_chance() -> float:
	return _loop.audit_chance()


## A hand type's level in this run.
func hand_level(type: int) -> int:
	return _loop.state.hand_levels.level_of(type as Pattern.Type)


## A hand type's Rate at a level, from the scorer's table.
func hand_rate(type: int, level: int) -> int:
	return Scorer.DEFAULT_PARAMS.rate_for(type, level)


## The highest level a hand type reaches.
func max_hand_level() -> int:
	return Scorer.DEFAULT_PARAMS.max_level

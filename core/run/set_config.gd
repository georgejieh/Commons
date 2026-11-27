class_name SetConfig
extends RefCounted
## Reads the run's shape from a SetParams Resource and checks it. Every Set number the
## run uses comes through here.

## Why validate() refuses a SetParams; OK means its numbers hold together.
enum Reason {
	OK,
	NO_YEARS,
	NO_ROUNDS,
	WRONG_TARGET_COUNT,
	NOT_POSITIVE,
	DECREASING,
	NO_REWARDS,
	BAD_OVERFULFILMENT,
}

## The run's Set numbers, from data: Years, targets, rewards and overfulfilment.
const DEFAULT_PARAMS: SetParams = preload("res://data/run/default_sets.tres")
## How many Sets a Year holds, one of each SetType.
const SETS_PER_YEAR: int = 3

var _params: SetParams


func _init(params: SetParams = DEFAULT_PARAMS) -> void:
	assert(validate(params) == Reason.OK)
	_params = params


## Targets must rise or hold from each Set to the next, across Years too.
static func validate(params: SetParams) -> Reason:
	if params.years < 1:
		return Reason.NO_YEARS
	if params.max_rounds < 1:
		return Reason.NO_ROUNDS
	if params.targets.size() != params.years * SETS_PER_YEAR:
		return Reason.WRONG_TARGET_COUNT
	if params.reward_coupons.size() != SETS_PER_YEAR:
		return Reason.NO_REWARDS
	var over: Array[int] = [
		params.over_max_steps, params.over_bonus_coupons, params.norm_percent_per_step
	]
	if params.over_step_percent < 1 or over.any(func(value: int) -> bool: return value < 0):
		return Reason.BAD_OVERFULFILMENT
	for index: int in params.targets.size():
		# Written this way round so NaN fails too.
		if not params.targets[index] > 0.0:
			return Reason.NOT_POSITIVE
		if index > 0 and params.targets[index] < params.targets[index - 1]:
			return Reason.DECREASING
	return Reason.OK


## This shape under a stake's numbers (ADR 0025): a new config whose targets are raised,
## or this one when the stake raises none.
func under_stake(sum: StakeDef) -> SetConfig:
	if sum.target_percent == 0:
		return self
	return SetConfig.new(RunStakes.sets(_params, sum))


## How many Years the run lasts.
func years() -> int:
	return _params.years


## The most rounds a Set may play.
func max_rounds() -> int:
	return _params.max_rounds


## year counts from 1.
func target(year: int, set_type: RunState.SetType) -> float:
	return _params.targets[(year - 1) * SETS_PER_YEAR + set_type]


## The coupons a finished Set of this type pays.
func reward(set_type: RunState.SetType) -> int:
	return _params.reward_coupons[set_type]


## A target under the norm: raised norm_percent(steps) percent, so steps add, not compound.
func normed(target_value: float, steps: int) -> float:
	if steps <= 0:
		return target_value
	return target_value * (100 + norm_percent(steps)) / 100.0


## The steps a Set earns by beating its target: one for each over_step_percent above it,
## up to over_max_steps. A missed target earns none.
func over_steps(progress: float, target_value: float) -> int:
	if not target_value > 0.0 or not progress >= target_value:
		return 0
	var over_percent: float = (progress - target_value) * 100.0 / target_value
	var steps: float = floorf(over_percent / _params.over_step_percent)
	return int(clampf(steps, 0.0, float(_params.over_max_steps)))


## Extra coupons for a Set's steps.
func over_bonus(steps: int) -> int:
	return steps * _params.over_bonus_coupons


## How far, in percent of the base target, steps raise every later target.
func norm_percent(steps: int) -> int:
	return steps * _params.norm_percent_per_step

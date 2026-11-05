class_name SetConfig
extends RefCounted
## Reads the run's shape from a SetParams Resource and checks it. Every Set number the
## run uses comes through here.

enum Reason { OK, NO_YEARS, NO_ROUNDS, WRONG_TARGET_COUNT, NOT_POSITIVE, DECREASING, NO_REWARDS }

const DEFAULT_PARAMS: SetParams = preload("res://data/run/default_sets.tres")
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
	for index: int in params.targets.size():
		# Written this way round so NaN fails too.
		if not params.targets[index] > 0.0:
			return Reason.NOT_POSITIVE
		if index > 0 and params.targets[index] < params.targets[index - 1]:
			return Reason.DECREASING
	return Reason.OK


func years() -> int:
	return _params.years


func max_rounds() -> int:
	return _params.max_rounds


## year counts from 1.
func target(year: int, set_type: RunState.SetType) -> float:
	return _params.targets[(year - 1) * SETS_PER_YEAR + set_type]


func reward(set_type: RunState.SetType) -> int:
	return _params.reward_coupons[set_type]

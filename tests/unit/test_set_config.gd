extends GdUnitTestSuite
## The run's shape comes from data, and a curve that falls is rejected.

const DEFAULT_PATH: String = "res://data/run/default_sets.tres"


func test_default_curve_is_valid() -> void:
	assert_int(SetConfig.validate(load(DEFAULT_PATH))).is_equal(SetConfig.Reason.OK)


func test_every_number_comes_from_the_params() -> void:
	var params: SetParams = _params()
	var config: SetConfig = SetConfig.new(params)
	assert_int(config.years()).is_equal(params.years)
	assert_int(config.max_rounds()).is_equal(params.max_rounds)
	for year: int in range(1, params.years + 1):
		for set_type: int in SetConfig.SETS_PER_YEAR:
			var index: int = (year - 1) * SetConfig.SETS_PER_YEAR + set_type
			var expected: float = params.targets[index]
			assert_float(config.target(year, set_type as RunState.SetType)).is_equal(expected)
	for set_type: int in SetConfig.SETS_PER_YEAR:
		var reward: int = config.reward(set_type as RunState.SetType)
		assert_int(reward).is_equal(params.reward_coupons[set_type])


func test_a_decreasing_curve_is_rejected() -> void:
	var params: SetParams = _params()
	params.targets[4] = params.targets[3] - 1.0
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.DECREASING)


func test_a_drop_between_years_is_rejected() -> void:
	var params: SetParams = _params()
	params.targets[3] = params.targets[2] - 1.0
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.DECREASING)


func test_a_flat_curve_is_accepted() -> void:
	var params: SetParams = _params()
	params.targets.fill(100.0)
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.OK)


func test_malformed_params_are_rejected() -> void:
	var params: SetParams = _params()
	params.targets.resize(params.targets.size() - 1)
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.WRONG_TARGET_COUNT)
	params = _params()
	params.max_rounds = 0
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.NO_ROUNDS)
	params = _params()
	params.targets[0] = 0.0
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.NOT_POSITIVE)
	params = _params()
	params.reward_coupons.clear()
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.NO_REWARDS)
	params = _params()
	params.targets[1] = NAN
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.NOT_POSITIVE)
	params = _params()
	params.reward_coupons.clear()
	assert_int(SetConfig.validate(params)).is_equal(SetConfig.Reason.NO_REWARDS)


## Distinct values everywhere, so a misread index shows.
func _params() -> SetParams:
	var params: SetParams = SetParams.new()
	params.years = 3
	params.max_rounds = 5
	for index: int in params.years * SetConfig.SETS_PER_YEAR:
		params.targets.append(100.0 + index * 7.0)
	params.reward_coupons.assign([2, 6, 9])
	return params

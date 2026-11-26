extends GdUnitTestSuite
## ADR 0032 in the balance harness: Relief Grain waits for 6 Famine and Self-Criticism for
## 6 Resentment, Self-Criticism never denounces the player to death, and every other
## Campaign is used as its rule allows.


func _params() -> BalanceParams:
	return BalanceDriver.PARAMS


func test_the_meter_campaigns_wait_until_they_help() -> void:
	var state: RunState = RunState.new(1)
	state.famine = 5
	state.resentment = 5
	assert_bool(BalanceWave.helps("relief_grain", state, _params())).is_false()
	assert_bool(BalanceWave.helps("self_criticism", state, _params())).is_false()
	state.famine = 6
	state.resentment = 6
	assert_bool(BalanceWave.helps("relief_grain", state, _params())).is_true()
	assert_bool(BalanceWave.helps("self_criticism", state, _params())).is_true()
	state.denunciation = RunDefaults.METERS.denunciation.death - 2
	assert_bool(BalanceWave.helps("self_criticism", state, _params())).is_false()
	assert_bool(BalanceWave.helps("grain_loan", state, _params())).is_true()


func test_the_wave_lists_every_new_piece_once() -> void:
	var ids: Dictionary[String, bool] = {}
	for item_id: String in BalanceWave.ITEMS:
		ids[item_id] = true
	assert_int(ids.size()).is_equal(19)
	for cadre: ModifierDef in RunLoop.all_cadres():
		if ids.has(cadre.id):
			ids.erase(cadre.id)
	for campaign: CampaignDef in RunCampaigns.all():
		if ids.has(campaign.id):
			ids.erase(campaign.id)
	assert_dict(ids).is_empty()

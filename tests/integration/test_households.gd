extends GdUnitTestSuite
## ADR 0025's households: each one's opening state exactly, its plot cards the same for a
## seed and plain cards of 10 to K, no setback fired before the run starts, and a
## household above the open tier refused with nothing written.

const DIR: String = "user://test_households/"
const PROFILE_PATH: String = DIR + "profile.json"
const START_TIME: int = 1_763_300_000
const BASE: int = 4

var _profile: SaveService


func before_test() -> void:
	_profile = Profile.service(PROFILE_PATH)
	_profile.delete()


func after_test() -> void:
	_profile.delete()


func _with_runs(finished: int) -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = finished
	Profile.write(_profile, data)


func _start(household: String, seed_value: int = 7100) -> RunState:
	var request: RunRequest = RunRequest.new(RunRequest.FULL, seed_value, START_TIME)
	request.household = household
	return RunStarter.state(request, _profile)


func test_poor_peasants_start_with_the_coupons_alone() -> void:
	var state: RunState = _start("poor_peasants")
	assert_int(state.coupons).is_equal(BASE)
	assert_array(state.inventory.plot).is_empty()
	assert_array(state.inventory.cadres).is_empty()
	assert_int(state.resentment).is_equal(0)
	assert_int(state.denunciation).is_equal(0)
	assert_str(state.identity.household).is_equal("poor_peasants")


func test_middle_peasants_start_with_two_plain_cards_of_ten_to_king() -> void:
	_with_runs(1)
	var state: RunState = _start("middle_peasants")
	assert_int(state.coupons).is_equal(BASE)
	assert_int(state.resentment).is_equal(5)
	assert_int(state.denunciation).is_equal(0)
	assert_int(state.inventory.plot.size()).is_equal(2)
	var ids: Dictionary[int, bool] = {}
	for card: CardInstance in state.inventory.plot:
		assert_int(card.origin()).is_equal(CardInstance.Origin.PLOT)
		assert_int(card.base_rank()).is_between(Ranks.TEN, Ranks.KING)
		assert_str(card.enhancement_id()).is_empty()
		assert_int(card.owner_stamp()).is_equal(CardInstance.NO_OWNER)
		ids[card.id()] = true
	assert_int(ids.size()).is_equal(2)
	assert_bool(state.inventory.plot[0].id() >= CardInstance.FIRST_PLOT_ID).is_true()
	assert_bool(state.next_plot_id > state.inventory.plot[1].id()).is_true()


func test_a_households_cards_are_the_same_for_a_seed_and_vary_across_seeds() -> void:
	_with_runs(1)
	var drawn: Dictionary[String, bool] = {}
	var suits: Dictionary[int, bool] = {}
	for seed_value: int in 40:
		var first: RunState = _start("middle_peasants", 7200 + seed_value)
		var again: RunState = _start("middle_peasants", 7200 + seed_value)
		assert_str(_cards(first)).is_equal(_cards(again))
		drawn[_cards(first)] = true
		for card: CardInstance in first.inventory.plot:
			suits[card.suit()] = true
	assert_int(drawn.size()).is_greater(20)
	assert_int(suits.size()).is_equal(Deck.SUITS)


func test_shopkeepers_start_with_six_more_coupons() -> void:
	_with_runs(2)
	var state: RunState = _start("shopkeepers")
	assert_int(state.coupons).is_equal(BASE + 6)
	assert_int(state.resentment).is_equal(10)
	assert_int(state.denunciation).is_equal(0)
	assert_array(state.inventory.plot).is_empty()


func test_the_old_family_starts_with_landlords_ledger_and_a_name() -> void:
	_with_runs(3)
	var state: RunState = _start("old_family")
	assert_int(state.coupons).is_equal(BASE)
	assert_array(state.inventory.cadres).contains_exactly(["landlords_ledger"])
	assert_bool(state.cadre_memos.has("landlords_ledger")).is_true()
	assert_int(state.resentment).is_equal(15)
	assert_int(state.denunciation).is_equal(10)
	# Nothing has risen through mid: no setback is owed or in force, and both stay armed.
	assert_bool(state.reeducation_due).is_false()
	assert_bool(state.rationed).is_false()
	assert_bool(state.denunciation_armed).is_true()
	assert_bool(state.famine_armed).is_true()


func test_the_opening_fires_no_setback_and_saves_what_it_set() -> void:
	_with_runs(3)
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 7300, START_TIME)
	request.household = "old_family"
	var controller: RunController = auto_free(RunController.new())
	assert_bool(controller.start(request, null, _profile)).is_true()
	for event: RunEvent in controller.set_events():
		assert_int(event.type).is_not_equal(RunEvent.Type.SETBACK)
	var loop: RunLoop = controller.get("_loop")
	var checkpoint: RunState = RunState.from_dict(loop.record.to_dict()["checkpoint"])
	assert_array(checkpoint.inventory.cadres).contains_exactly(["landlords_ledger"])
	assert_int(checkpoint.denunciation).is_equal(10)
	assert_int(checkpoint.resentment).is_equal(15)


func test_a_household_above_the_open_tier_is_refused() -> void:
	_with_runs(1)
	for locked: String in ["shopkeepers", "old_family", "no_such_household"]:
		assert_object(_start(locked)).override_failure_message(locked).is_null()
	assert_int(Profile.read(_profile).generation).is_equal(0)
	var controller: RunController = auto_free(RunController.new())
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 7400, START_TIME)
	request.household = "old_family"
	assert_bool(controller.start(request, null, _profile)).is_false()
	assert_bool(controller.has_run()).is_false()
	assert_object(_start("middle_peasants")).is_not_null()


func test_the_four_households_are_the_adrs() -> void:
	var pool: HouseholdPool = RunStarter.HOUSEHOLDS
	var rows: Array[Array] = [
		["poor_peasants", 0, 0, 0, "", 0, 0],
		["middle_peasants", 1, 0, 2, "", 5, 0],
		["shopkeepers", 2, 6, 0, "", 10, 0],
		["old_family", 3, 0, 0, "landlords_ledger", 15, 10],
	]
	assert_int(pool.households.size()).is_equal(rows.size())
	for index: int in rows.size():
		var row: Array = rows[index]
		var household: HouseholdDef = pool.households[index]
		var got: Array = [
			household.id,
			household.unlock_tier,
			household.coupons,
			household.plot_cards,
			household.cadre_id,
			household.resentment,
			household.denunciation,
		]
		assert_array(got).is_equal(row)
		assert_int(household.plot_low_rank).is_equal(Ranks.TEN)
		assert_int(household.plot_high_rank).is_equal(Ranks.KING)
		for key: String in [household.name_key, household.text_key]:
			assert_str(tr(key)).is_not_equal(key)


func _cards(state: RunState) -> String:
	var parts: PackedStringArray = []
	for card: CardInstance in state.inventory.plot:
		parts.append("%d:%d:%d" % [card.id(), card.base_rank(), card.suit()])
	return ",".join(parts)

extends GdUnitTestSuite
## ADR 0025's unlocks. A full run is offered only items whose tier is at or below the
## finished runs it started from, by every way an item can be offered or handed over:
## both counters' Cadres through rerolls, Directives, Campaigns, Reforms, the envelope
## kinds and what they hold, and reeducation's exchange. Held items of a locked tier still
## work, a demo is never filtered, and a save keeps the pools it started with. Tier 0
## fills every counter. Families join the village by finished runs and a landlord ending.

const SEEDS: int = 60
const REROLLS: int = 4
const RICH: int = 10000
const DIR: String = "user://test_unlocks/"
const RUN_PATH: String = DIR + "run.json"
const PROFILE_PATH: String = DIR + "profile.json"

var _saves: SaveService
var _profile: SaveService


func before_test() -> void:
	_saves = SaveService.for_run(RUN_PATH)
	_profile = Profile.service(PROFILE_PATH)
	_saves.delete()
	_profile.delete()


func after_test() -> void:
	_saves.delete()
	_profile.delete()


func _full_state(seed_value: int, finished: int) -> RunState:
	var state: RunState = RunState.new(seed_value)
	state.identity.kind = RunIdentity.Kind.FULL
	state.identity.finished_runs = finished
	return state


func _loop(state: RunState) -> RunLoop:
	return RunLoop.new(state, RunScript.bots(), SetConfig.new())


## Every ID of a kind with its tier.
func _tiers() -> Dictionary[String, int]:
	var items: Array[Resource] = []
	items.append_array(RunLoop.all_cadres())
	items.append_array(RunPools.DIRECTIVES.directives)
	items.append_array(RunCampaigns.all())
	items.append_array(RunReforms.all())
	items.append_array(RunPools.STORE.envelopes + RunPools.MARKET.envelopes)
	var tiers: Dictionary[String, int] = {}
	for item: Resource in items:
		tiers[str(item.get("id"))] = int(item.get("unlock_tier"))
	return tiers


func _assert_open(ids: Array[String], tiers: Dictionary[String, int], finished: int) -> void:
	for item_id: String in ids:
		if item_id.is_empty():
			continue
		(
			assert_int(tiers[item_id])
			. override_failure_message("%s offered at %d runs" % [item_id, finished])
			. is_less_equal(finished)
		)


## Everything both counters show in one visit, rerolls included.
func _visit(loop: RunLoop, tiers: Dictionary[String, int], finished: int) -> void:
	loop.state.coupons = RICH
	for counter: RunShop in [loop.shop, loop.market]:
		counter.open()
	loop.shop.stock_directives()
	for draws: int in REROLLS + 1:
		for counter: RunShop in [loop.shop, loop.market]:
			counter.campaigns.draw()
			counter.reforms.draw()
			counter.envelopes.draw()
			_assert_open(counter.stock(), tiers, finished)
			_assert_open(counter.directive_stock(), tiers, finished)
			_assert_open(counter.campaigns.stock(), tiers, finished)
			_assert_open(counter.reforms.stock(), tiers, finished)
			_assert_open(counter.envelopes.stock(), tiers, finished)
		if draws < REROLLS:
			loop.shop.reroll()
			loop.market.reroll()


## Each envelope a counter sells, bought and opened: every item it shows is open.
func _envelopes(loop: RunLoop, tiers: Dictionary[String, int], finished: int) -> void:
	for counter: RunShop in [loop.shop, loop.market]:
		if counter.envelopes.stock().is_empty():
			continue
		assert_int(counter.envelopes.buy(0)).is_equal(RunShop.Reason.OK)
		for item: EnvelopeItem in counter.envelopes.items():
			if not item.item_id.is_empty():
				_assert_open([item.item_id], tiers, finished)
		counter.envelopes.pick(EnvelopeCounter.NOTHING, RunLoop.PLAYER)


func test_every_offer_path_draws_only_open_items() -> void:
	var tiers: Dictionary[String, int] = _tiers()
	for finished: int in [0, 1, 2, 3]:
		var reached: Dictionary[int, bool] = {}
		for seed_value: int in SEEDS:
			var loop: RunLoop = _loop(_full_state(seed_value, finished))
			_visit(loop, tiers, finished)
			_envelopes(loop, tiers, finished)
			for item_id: String in loop.shop.stock() + loop.market.stock():
				if not item_id.is_empty():
					reached[tiers[item_id]] = true
			# Reeducation's exchange, from every Cadre held in turn.
			var inventory: RunInventory = RunInventory.new()
			inventory.cadres.assign(["landlords_ledger"])
			var stream: RandomStream = RandomStream.new(seed_value)
			var change: PackedStringArray = Reeducation.change_cadre(
				inventory, loop.pools.exchange(), stream
			)
			_assert_open([change[1]], tiers, finished)
		# Over many seeds the newest open tier is offered too, so the filter is not too tight.
		assert_bool(reached.has(finished)).override_failure_message(str(finished)).is_true()


func test_the_loop_exchanges_only_an_open_cadre_at_reeducation() -> void:
	var tiers: Dictionary[String, int] = _tiers()
	for seed_value: int in 6:
		var state: RunState = _full_state(6100 + seed_value, 0)
		state.inventory.cadres.assign(["rehabilitation"])
		var loop: RunLoop = _loop(state)
		loop.start_set()
		RunScript.new().play_until_set_over(loop)
		loop.state.reeducation_due = true
		assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
		_assert_open(loop.state.inventory.cadres, tiers, 0)


func test_a_held_item_of_a_locked_tier_still_works_after_a_load() -> void:
	var state: RunState = _full_state(6200, 0)
	state.inventory.cadres.assign(["rehabilitation", "steel_target"])
	state.inventory.consumables.assign(["seizure_notice"])
	state.reforms.assign(["unplanned_economy"])
	var loop: RunLoop = _loop(state)
	loop.start_set()
	var saved: Dictionary = loop.record.to_dict()
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.inventory.cadres).contains_exactly(
		["rehabilitation", "steel_target"]
	)
	assert_object(resumed.campaigns.definition("seizure_notice")).is_not_null()
	assert_bool(RunReforms.gathers_deck(resumed.state)).is_true()
	# The held Cadres are in play: the view and the round read their definitions.
	RunScript.new().play_until_set_over(resumed)
	assert_int(resumed.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)
	assert_bool(resumed.pools.store_cadres.any(_is("seed_grain"))).is_false()


func test_a_demo_run_is_never_filtered() -> void:
	var loop: RunLoop = _loop(RunState.new(6300))
	assert_int(loop.pools.store_cadres.size()).is_equal(RunLoop.DEFAULT_CADRES.cadres.size())
	assert_int(loop.pools.market_cadres.size()).is_equal(RunLoop.DEFAULT_MARKET.cadres.size())
	assert_int(loop.pools.reforms.size()).is_equal(RunReforms.all().size())
	var campaigns: int = loop.pools.store_campaigns.size() + loop.pools.market_campaigns.size()
	assert_int(campaigns).is_equal(RunCampaigns.all().size())
	assert_int(loop.pools.exchange().size()).is_equal(RunLoop.all_cadres().size())


func test_a_save_keeps_the_pools_it_started_with() -> void:
	var data: ProfileData = ProfileData.new()
	data.finished_runs = 1
	Profile.write(_profile, data)
	var controller: RunController = auto_free(RunController.new())
	var request: RunRequest = RunRequest.new(RunRequest.FULL, 6400, 1)
	assert_bool(controller.start(request, _saves, _profile)).is_true()
	assert_int(controller.state_copy().identity.finished_runs).is_equal(1)
	# The profile moves on to three finished runs while the run is saved.
	data = Profile.read(_profile)
	data.finished_runs = 3
	Profile.write(_profile, data)
	var resumed: RunController = auto_free(RunController.new())
	assert_bool(resumed.continue_saved(_saves, _profile)).is_true()
	var loop: RunLoop = resumed.get("_loop")
	assert_int(loop.state.identity.finished_runs).is_equal(1)
	var open: int = (
		RunLoop
		. DEFAULT_CADRES
		. cadres
		. filter(func(item: ModifierDef) -> bool: return item.unlock_tier <= 1)
		. size()
	)
	assert_int(loop.pools.store_cadres.size()).is_equal(open)
	assert_bool(loop.pools.store_cadres.any(_is("seed_grain"))).is_false()
	assert_bool(loop.pools.store_cadres.any(_is("model_commune"))).is_true()


## Tier 0 alone fills every counter a first run visits.
func test_tier_zero_fills_every_counter() -> void:
	var loop: RunLoop = _loop(_full_state(6500, 0))
	var store: ShopParams = RunPools.STORE
	var market: ShopParams = RunPools.MARKET
	assert_int(loop.pools.store_cadres.size()).is_greater_equal(store.slots)
	assert_int(loop.pools.market_cadres.size()).is_greater_equal(market.slots)
	assert_int(loop.pools.directives.size()).is_greater_equal(store.directive_slots)
	assert_int(loop.pools.store_campaigns.size()).is_greater_equal(store.campaign_offers)
	assert_int(loop.pools.market_campaigns.size()).is_greater_equal(market.campaign_offers)
	assert_int(loop.pools.reforms.size()).is_greater_equal(store.reform_offers)
	assert_int(loop.pools.store.envelopes.size()).is_equal(store.envelopes.size())
	assert_int(loop.pools.market.envelopes.size()).is_equal(market.envelopes.size())
	for tier: int in 4:
		print("tier %d: %s" % [tier, _counts(tier)])


func _counts(tier: int) -> String:
	var pools: Dictionary[String, Array] = {
		"store cadres": RunPools.STORE_CADRES.cadres,
		"market cadres": RunPools.MARKET_CADRES.cadres,
		"directives": RunPools.DIRECTIVES.directives,
		"store campaigns": RunPools.STORE_CAMPAIGNS.campaigns,
		"market campaigns": RunPools.MARKET_CAMPAIGNS.campaigns,
		"reforms": RunPools.REFORMS.reforms,
		"envelopes": RunPools.STORE.envelopes + RunPools.MARKET.envelopes,
	}
	var parts: PackedStringArray = []
	for pool: String in pools:
		var count: int = 0
		for item: Resource in pools[pool]:
			if int(item.get("unlock_tier")) == tier:
				count += 1
		parts.append("%s %d" % [pool, count])
	return ", ".join(parts)


func test_families_join_the_village_by_finished_runs() -> void:
	var expected: Dictionary[int, Array] = {
		0: [],
		1: ["xu"],
		2: ["xu", "zhou"],
		3: ["xu", "zhou", "ma"],
		4: ["xu", "zhou", "ma", "feng"],
		5: ["xu", "zhou", "ma", "feng", "tang"],
	}
	for runs: int in expected:
		var data: ProfileData = ProfileData.new()
		data.finished_runs = runs
		var unlocked: Array[String] = RunStarter.unlocked_families(data)
		assert_array(unlocked).override_failure_message(str(runs)).contains_exactly(expected[runs])


func test_deng_joins_after_a_landlord_ending_and_not_a_landlords_death() -> void:
	var data: ProfileData = ProfileData.new()
	assert_array(RunStarter.unlocked_families(data)).not_contains(["deng"])
	data.landlord_endings = 1
	assert_array(RunStarter.unlocked_families(data)).contains(["deng"])
	# The roster a full run starts with holds what the profile unlocked.
	data.finished_runs = 1
	Profile.write(_profile, data)
	var state: RunState = RunStarter.state(RunRequest.new(RunRequest.FULL, 6600, 1), _profile)
	assert_object(Roster.entry(state, "deng")).is_not_null()
	assert_object(Roster.entry(state, "xu")).is_not_null()
	assert_object(Roster.entry(state, "zhou")).is_null()


## The count is raised by a finished full run's landlord ending, never by a landlord's
## death or a peasant's ending, and it outlives the history's cap.
func test_a_landlord_ending_is_counted_and_outlives_the_history() -> void:
	var cases: Dictionary[String, Array] = {
		"landlord_death": [4, 100, 0],
		"peasant_ending": [0, 10, 0],
		"landlord_ending": [4, 10, 1],
	}
	for name: String in cases:
		_profile.delete()
		var state: RunState = RunState.new(6700)
		state.identity.id = "run-" + name
		state.identity.kind = RunIdentity.Kind.FULL
		state.phase = RunFlow.State.RUN_END
		state.year = 8
		state.year_rounds = 4
		state.year_landlord_rounds = cases[name][0]
		state.famine = cases[name][1]
		ProfileCommits.commit(_profile, state, true)
		var counted: int = Profile.read(_profile).landlord_endings
		assert_int(counted).override_failure_message(name).is_equal(cases[name][2])
	var data: ProfileData = Profile.read(_profile)
	for index: int in ProfileData.HISTORY_CAP:
		var later: HistoryEntry = _entry(HistoryEntry.PEASANT, Endings.SECRET_CONTRACT)
		later.run_id = "later-%d" % index
		data.add_history(later)
	Profile.write(_profile, data)
	var capped: ProfileData = Profile.read(_profile)
	assert_int(capped.history_landlord_endings()).is_equal(0)
	assert_array(RunStarter.unlocked_families(capped)).contains(["deng"])


## A schema 2 profile written before the count existed reads it from its history, and the
## rest of its validation stays strict.
func test_a_profile_from_before_the_count_reads_it_from_its_history() -> void:
	var data: ProfileData = ProfileData.new()
	data.history.append(_entry(HistoryEntry.LANDLORD, Endings.DEATH_FAMINE))
	data.history.append(_entry(HistoryEntry.PEASANT, Endings.SECRET_CONTRACT))
	data.history.append(_entry(HistoryEntry.LANDLORD, Endings.FULL_GRANARY))
	var old: Dictionary = data.to_dict()
	old.erase(ProfileData.LANDLORD_ENDINGS_KEY)
	assert_bool(Profile.is_valid(old)).is_true()
	var read: ProfileData = ProfileData.from_dict(old)
	assert_int(read.landlord_endings).is_equal(1)
	assert_array(RunStarter.unlocked_families(read)).contains(["deng"])
	old[ProfileData.LANDLORD_ENDINGS_KEY] = -1
	assert_bool(Profile.is_valid(old)).is_false()
	old[ProfileData.LANDLORD_ENDINGS_KEY] = 1.5
	assert_bool(Profile.is_valid(old)).is_false()


func _entry(class_id: String, outcome: String) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new()
	entry.class_id = class_id
	entry.outcome = outcome
	return entry


func _is(item_id: String) -> Callable:
	return func(item: ModifierDef) -> bool: return item.id == item_id

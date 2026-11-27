extends GdUnitTestSuite
## Reforms (ADR 0021): the state store offers one a visit, the same for the same seed,
## never one held or held back (none is, now that envelopes exist), redrawn by a reroll;
## buying one needs the coupons and is a saved command; and each of the six does what
## its rule says, up to its limit, in every place that reads it.

const POOL: ReformPool = preload("res://data/run/reform_pool.tres")
const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const SETS: SetParams = preload("res://data/run/default_sets.tres")
const METERS: MeterTable = preload("res://data/run/meters.tres")
const SEEDS: int = 24
const RICH: int = 1000


func _at_the_shops(seed_value: int, reforms: Array[String] = []) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.reforms.assign(reforms)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	# Handed over at the Set's end, where the record's checkpoint is, so a replay has them.
	loop.state.coupons = RICH
	loop.record.mark(loop.state)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


## A curve every Set beats in its first round, or one no Set can meet.
func _sets(target: float) -> SetConfig:
	var params: SetParams = SETS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(target)
	return SetConfig.new(params)


func _played_set(seed_value: int, reforms: Array[String], sets: SetConfig) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.reforms.assign(reforms)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), sets)
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	return loop


func test_the_pool_holds_adr_0021s_six_reforms_and_adr_0029s_two() -> void:
	var ids: Array[String] = []
	for reform: ReformDef in POOL.reforms:
		ids.append(reform.id)
		assert_bool(ReformRegistry.has_effect(reform.id)).is_true()
	(
		assert_array(ids)
		. contains_exactly(
			[
				"supply_cooperative",
				"work_point_reform",
				"enlarged_committee",
				"grain_reserve",
				"couriers_bag",
				"unplanned_economy",
				"mass_line",
				"industrialization",
			]
		)
	)
	assert_int(STORE.reform_offers).is_equal(1)
	assert_int(MARKET.reform_offers).is_equal(0)


func test_the_store_offers_one_reform_the_same_for_the_same_seed() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: RunLoop = _at_the_shops(seed_value)
		var second: RunLoop = _at_the_shops(seed_value)
		var offer: Array[String] = first.shop.reforms.stock()
		assert_int(offer.size()).is_equal(1)
		assert_array(offer).is_equal(second.shop.reforms.stock())
		assert_array(first.market.reforms.stock()).is_empty()
		assert_int(first.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_int(second.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(first.shop.reforms.stock()).is_equal(second.shop.reforms.stock())
		seen[offer[0]] = true
	# Every Reform a run outside the profile may be offered turns up across the seeds, Supply
	# Cooperative too; the wild ranks' tier is not among them (ADR 0029).
	assert_int(seen.size()).is_equal(RunPools.new(RunState.new(0).identity).reforms.size())
	assert_bool(seen.has("mass_line") or seen.has("industrialization")).is_false()


## The draw comes last on the shop stream, so every other draw is as it was.
func test_the_reform_draw_leaves_the_other_stock_alone() -> void:
	for seed_value: int in 6:
		var loop: RunLoop = _at_the_shops(seed_value)
		# The same run with a Reform counter that offers nothing.
		var bare: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
		bare.shop.reforms = ReformCounter.new(bare.state, MARKET, POOL.reforms)
		bare.start_set()
		RunScript.new().play_until_set_over(bare)
		bare.state.coupons = RICH
		bare.open_shop()
		assert_array(bare.shop.reforms.stock()).is_empty()
		assert_array(bare.shop.stock()).is_equal(loop.shop.stock())
		assert_array(bare.market.stock()).is_equal(loop.market.stock())
		assert_array(bare.shop.campaigns.stock()).is_equal(loop.shop.campaigns.stock())
		assert_array(bare.shop.directive_stock()).is_equal(loop.shop.directive_stock())


func test_a_held_or_held_back_reform_is_never_offered() -> void:
	var held: Array[String] = ["work_point_reform", "grain_reserve", "couriers_bag"]
	for seed_value: int in SEEDS:
		var loop: RunLoop = _at_the_shops(seed_value, held)
		for _reroll: int in 3:
			var offer: Array[String] = loop.shop.reforms.stock()
			assert_bool(held.has(offer[0])).is_false()
			loop.player_reroll()
	# A Reform held back in data is never offered.
	var held_back: ReformDef = RunReforms.definition("work_point_reform").duplicate()
	held_back.held_back = true
	var one: Array[ReformDef] = [held_back]
	var withheld: ReformCounter = ReformCounter.new(RunState.new(1), STORE, one)
	withheld.draw()
	assert_array(withheld.stock()).is_empty()
	var state: RunState = RunState.new(1)
	state.reforms.assign(["work_point_reform", "enlarged_committee", "grain_reserve"])
	state.reforms.append_array(["couriers_bag", "unplanned_economy", "supply_cooperative"])
	state.reforms.append_array(["mass_line", "industrialization"])
	var counter: ReformCounter = ReformCounter.new(state, STORE, POOL.reforms)
	counter.draw()
	assert_array(counter.stock()).is_empty()
	assert_bool(counter.reroll_changes()).is_false()


func test_buying_needs_the_coupons_and_is_a_saved_command() -> void:
	var loop: RunLoop = _at_the_shops(3)
	var offered: String = loop.shop.reforms.stock()[0]
	var price: int = loop.shop.reforms.price(0)
	assert_int(price).is_equal(RunReforms.definition(offered).cost)
	loop.state.coupons = price - 1
	var commands: int = loop.record.commands.size()
	assert_int(loop.player_reform(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_array(loop.state.reforms).is_empty()
	assert_int(loop.record.commands.size()).is_equal(commands)
	loop.state.coupons = price
	assert_int(loop.player_reform(0)).is_equal(RunLoop.Reason.OK)
	assert_array(loop.state.reforms).is_equal([offered])
	assert_int(loop.state.coupons).is_equal(0)
	assert_dict(loop.record.commands[-1]).is_equal({"type": "reform", "slot": 0})
	assert_int(loop.player_reform(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.next_set()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_reform(0)).is_equal(RunLoop.Reason.NOT_AWAITED)


## Bought, saved, loaded and replayed, the Reform is still in force.
func test_held_reforms_survive_save_load_and_replay() -> void:
	var loop: RunLoop = _at_the_shops(8)
	loop.state.coupons = RICH
	var offered: String = loop.shop.reforms.stock()[0]
	assert_int(loop.player_reform(0)).is_equal(RunLoop.Reason.OK)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
	assert_bool(RunRecord.is_valid(saved)).is_true()
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_array(resumed.state.reforms).is_equal([offered])
	assert_str(JSON.stringify(resumed.state.to_dict())).is_equal(
		JSON.stringify(loop.state.to_dict())
	)
	loop.next_set()
	var at_start: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
	var later: RunLoop = RunRecord.resume(at_start, RunScript.bots(), SetConfig.new())
	assert_array(later.state.reforms).is_equal([offered])


func test_work_point_reform_pays_only_on_a_met_quota() -> void:
	var easy: SetConfig = _sets(0.01)
	var plain: RunLoop = _played_set(41, [], easy)
	var reformed: RunLoop = _played_set(41, ["work_point_reform"], easy)
	assert_bool(plain.state.set_progress >= plain.target()).is_true()
	var extra: int = RunReforms.definition("work_point_reform").parameters["coupons"]
	assert_int(reformed.state.coupons).is_equal(plain.state.coupons + extra)
	var hard: SetConfig = _sets(1e9)
	var missed: RunLoop = _played_set(41, ["work_point_reform"], hard)
	assert_int(missed.state.coupons).is_equal(_played_set(41, [], hard).state.coupons)


func test_grain_reserve_takes_famine_off_a_miss_down_to_none() -> void:
	var hard: SetConfig = _sets(1e9)
	var plain: RunLoop = _played_set(52, [], hard)
	var reserved: RunLoop = _played_set(52, ["grain_reserve"], hard)
	var relief: int = RunReforms.definition("grain_reserve").parameters["famine"]
	var amount: int = METERS.source(RunMeters.MISSED_TARGET).amount
	assert_int(plain.state.famine - reserved.state.famine).is_equal(mini(relief, amount))
	var state: RunState = RunState.new(1)
	state.reforms.append("grain_reserve")
	assert_int(RunReforms.missed_famine(state, amount)).is_equal(amount - relief)
	assert_int(RunReforms.missed_famine(state, relief)).is_equal(0)
	assert_int(RunReforms.missed_famine(state, relief - 1)).is_equal(0)
	assert_int(RunReforms.missed_famine(RunState.new(1), amount)).is_equal(amount)
	# A met Quota adds no Famine either way.
	var easy: RunLoop = _played_set(52, ["grain_reserve"], _sets(0.01))
	assert_int(easy.state.famine).is_equal(_played_set(52, [], _sets(0.01)).state.famine)


func test_enlarged_committee_raises_the_one_cadre_limit_everywhere() -> void:
	var loop: RunLoop = _at_the_shops(9)
	var five: Array[String] = ["iron_rice_bowl", "canteen", "red_banner", "peek", "red_ink"]
	loop.state.inventory.cadres.assign(five)
	assert_int(RunReforms.cadre_slots(loop.state)).is_equal(STORE.cadre_slots)
	assert_bool(loop.shop.has_room()).is_false()
	assert_bool(loop.market.has_room()).is_false()
	loop.state.reforms.append("enlarged_committee")
	assert_int(RunReforms.cadre_slots(loop.state)).is_equal(STORE.cadre_slots + 1)
	assert_bool(loop.shop.has_room()).is_true()
	assert_bool(loop.market.has_room()).is_true()
	assert_int(loop.player_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.inventory.cadres.size()).is_equal(6)
	assert_bool(loop.shop.has_room()).is_false()
	assert_int(loop.player_market_buy(_rankless(loop))).is_equal(RunLoop.Reason.ILLEGAL)
	# Reeducation exchanges one of the six in its place; The Purge takes from all six.
	var stream: RandomStream = RandomStream.new(4)
	var all_cadres: Array[ModifierDef] = RunLoop.all_cadres()
	var change: PackedStringArray = Reeducation.change_cadre(
		loop.state.inventory, all_cadres, stream
	)
	assert_int(change.size()).is_equal(2)
	assert_int(loop.state.inventory.cadres.size()).is_equal(6)
	var purged: Array[String] = Bosses.purge(loop.state.inventory, 1, stream)
	assert_int(purged.size()).is_equal(1)
	assert_int(loop.state.inventory.cadres.size()).is_equal(5)


## A black market slot whose Cadre needs no rank, so only the limit can refuse it.
func _rankless(loop: RunLoop) -> int:
	var stock: Array[String] = loop.market.stock()
	for slot: int in stock.size():
		for cadre: ModifierDef in RunLoop.all_cadres():
			if cadre.id == stock[slot] and not cadre.needs_rank:
				return slot
	return 0


func test_couriers_bag_raises_the_campaign_limit_at_both_shops() -> void:
	var loop: RunLoop = _at_the_shops(10)
	loop.state.inventory.consumables.assign(["grain_loan", "appeal"])
	assert_bool(loop.shop.campaigns.has_room()).is_false()
	assert_bool(loop.market.campaigns.has_room()).is_false()
	loop.state.reforms.append("couriers_bag")
	assert_int(RunReforms.campaign_slots(loop.state)).is_equal(STORE.campaign_slots + 1)
	assert_bool(loop.market.campaigns.has_room()).is_true()
	assert_int(loop.player_campaign_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.inventory.consumables.size()).is_equal(3)
	assert_int(loop.player_market_campaign(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.market.campaigns.check(0)).is_equal(RunShop.Reason.CAMPAIGNS_FULL)


func test_supply_cooperative_reports_its_extra_envelope_choice() -> void:
	var state: RunState = RunState.new(1)
	assert_int(RunReforms.extra_envelope_choices(state)).is_equal(0)
	state.reforms.append("supply_cooperative")
	var choices: int = RunReforms.definition("supply_cooperative").parameters["choices"]
	assert_int(choices).is_equal(1)
	assert_int(RunReforms.extra_envelope_choices(state)).is_equal(choices)
	# Envelopes exist, so the state store can offer it.
	assert_bool(RunReforms.definition("supply_cooperative").held_back).is_false()
	# Its only effect is the envelope accessor: no limit, payment or deal changes.
	assert_int(RunReforms.cadre_slots(state)).is_equal(STORE.cadre_slots)
	assert_int(RunReforms.quota_coupons(state)).is_equal(0)
	assert_bool(RunReforms.gathers_deck(state)).is_false()


## A schema 7 save gains no Reforms and no gathered deck; damaged shapes are damage.
func test_a_schema_7_save_migrates_and_bad_shapes_fail() -> void:
	assert_int(SaveService.SCHEMA_VERSION).is_greater_equal(8)
	var record: RunRecord = RunRecord.new()
	var state: RunState = RunState.new(77)
	state.coupons = 6
	record.mark(state)
	var data: Dictionary = record.to_dict()
	var checkpoint: Dictionary = data["checkpoint"]
	checkpoint.erase("reforms")
	checkpoint.erase("deck_order")
	assert_bool(RunRecord.is_valid(data)).is_false()
	var dir: String = "user://test_reforms/"
	DirAccess.make_dir_recursive_absolute(dir)
	var service: SaveService = SaveService.for_run(dir + "run.json")
	service.delete()
	var file: FileAccess = FileAccess.open(service.path(), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 7, "data": data}))
	file.close()
	var loaded: SaveLoad = service.load_save()
	assert_int(loaded.status).is_equal(SaveLoad.Status.OK)
	var migrated: RunState = RunState.from_dict(loaded.data["checkpoint"])
	assert_array(migrated.reforms).is_empty()
	assert_array(migrated.deck_order).is_empty()
	assert_int(migrated.coupons).is_equal(6)
	service.delete()
	var wrong: Array[Dictionary] = [
		{"reforms": {}},
		{"reforms": [3]},
		{"deck_order": [1, 2, 3]},
		{"deck_order": range(53) + [0]},
		{"deck_order": {}},
	]
	for change: Dictionary in wrong:
		var bad: Dictionary = record.to_dict()
		var bad_checkpoint: Dictionary = bad["checkpoint"]
		bad_checkpoint.merge(change, true)
		assert_bool(RunRecord.is_valid(bad)).override_failure_message(str(change)).is_false()
	var fine: Dictionary = record.to_dict()
	var fine_checkpoint: Dictionary = fine["checkpoint"]
	fine_checkpoint.merge({"deck_order": range(Deck.SIZE), "reforms": ["x"]}, true)
	assert_bool(RunRecord.is_valid(fine)).is_true()
	var text: String = JSON.stringify(fine_checkpoint)
	var round_trip: RunState = RunState.from_dict(JSON.parse_string(text))
	assert_int(round_trip.deck_order.size()).is_equal(Deck.SIZE)
	assert_array(round_trip.reforms).is_equal(["x"])

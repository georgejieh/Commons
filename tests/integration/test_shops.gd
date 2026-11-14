extends GdUnitTestSuite
## The two shops between Sets (P4.10). The state store sells collective Cadres cheaply
## from a limited stock; the black market sells private ones dearer, with no limit, and
## every purchase there raises Resentment. Both draw stock on the shop stream, so a
## seed always sees the same counters.

const STORE_POOL: CadrePool = preload("res://data/run/cadre_pool.tres")
const MARKET_POOL: CadrePool = preload("res://data/run/market_pool.tres")
const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const UPGRADES: PlotUpgradeParams = preload("res://data/run/plot_upgrades.tres")
const SEEDS: int = 200
## Enough for anything either counter sells.
const RICH: int = 1000


## A run that has finished its first Set and opened the shops, with coupons to spend.
func _at_the_shops(seed_value: int, coupons: int = RICH) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = coupons
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


func test_the_store_sells_collective_cadres_and_the_market_private_ones() -> void:
	assert_int(STORE_POOL.cadres.size()).is_greater(0)
	assert_int(MARKET_POOL.cadres.size()).is_greater(0)
	for definition: ModifierDef in STORE_POOL.cadres:
		assert_int(definition.tag).override_failure_message(definition.id).is_equal(
			ModifierDef.Tag.COLLECTIVE
		)
	for definition: ModifierDef in MARKET_POOL.cadres:
		assert_int(definition.tag).override_failure_message(definition.id).is_equal(
			ModifierDef.Tag.PRIVATE
		)


func test_both_counters_draw_the_same_stock_for_the_same_seed() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: RunLoop = _at_the_shops(seed_value)
		var second: RunLoop = _at_the_shops(seed_value)
		assert_array(first.shop.stock()).is_equal(second.shop.stock())
		assert_array(first.market.stock()).is_equal(second.market.stock())
		assert_int(first.market.stock().size()).is_equal(MARKET.slots)
		for item_id: String in first.market.stock():
			assert_bool(MARKET_POOL.cadres.any(_is(item_id))).is_true()
		# A reroll is a draw too, and is as repeatable.
		assert_int(first.player_market_reroll()).is_equal(RunLoop.Reason.OK)
		assert_int(second.player_market_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(first.market.stock()).is_equal(second.market.stock())
		seen[",".join(first.market.stock())] = true
	assert_int(seen.size()).is_greater(10)


func test_buying_from_the_black_market_always_raises_resentment() -> void:
	var bought: int = 0
	for seed_value: int in SEEDS:
		var loop: RunLoop = _at_the_shops(seed_value)
		for slot: int in loop.market.stock().size():
			if loop.market.check_buy(slot) != RunShop.Reason.OK:
				continue
			var before: int = loop.state.resentment
			var events: int = _resentment_events(loop)
			assert_int(loop.player_market_buy(slot)).is_equal(RunLoop.Reason.OK)
			assert_int(loop.state.resentment).is_greater(before)
			assert_int(_resentment_events(loop)).is_equal(events + 1)
			assert_str(loop.events()[-1].text).is_equal(Resentment.PRIVATE_PURCHASE)
			bought += 1
	assert_int(bought).is_greater(SEEDS)


func test_a_refused_market_purchase_raises_nothing() -> void:
	var loop: RunLoop = _at_the_shops(11, 0)
	var before: int = loop.state.resentment
	assert_int(loop.player_market_buy(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.state.resentment).is_equal(before)
	assert_int(loop.player_upgrade(PlotUpgrades.CAPACITY)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.state.resentment).is_equal(before)


func test_the_state_store_never_raises_resentment() -> void:
	var loop: RunLoop = _at_the_shops(12)
	var before: int = loop.state.resentment
	for slot: int in loop.shop.stock().size():
		assert_int(loop.player_buy(slot)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.resentment).is_equal(before)


func test_the_market_charges_more_than_the_store_for_the_same_cost() -> void:
	var state: RunState = RunState.new(5)
	var store: RunShop = RunShop.new(state, STORE, MARKET_POOL.cadres)
	var market: RunShop = RunShop.new(state, MARKET, MARKET_POOL.cadres)
	store.open()
	market.open()
	for slot: int in store.stock().size():
		var item_id: String = store.stock()[slot]
		var across: int = market.stock().find(item_id)
		if across >= 0:
			assert_int(market.price(across)).is_greater(store.price(slot))
	# 150% of 5 is 7.5, rounded up.
	assert_int(MARKET.price_percent).is_equal(150)
	var dear: RunShop = RunShop.new(RunState.new(1), MARKET, [_costing(5)])
	dear.open()
	assert_int(dear.price(0)).is_equal(8)


func test_the_state_store_runs_out_of_an_item_and_the_market_does_not() -> void:
	var loop: RunLoop = _at_the_shops(13)
	var item_id: String = loop.shop.stock()[0]
	assert_int(loop.shop.left(item_id)).is_equal(STORE.stock_per_item)
	assert_int(loop.player_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.shop.left(item_id)).is_equal(0)
	# Lost again, as to a purge, it is still not restocked.
	loop.state.inventory.cadres.erase(item_id)
	for _reroll: int in 5:
		loop.player_reroll()
		assert_array(loop.shop.stock()).not_contains([item_id])
	assert_int(loop.market.left(loop.market.stock()[0])).is_equal(-1)
	# The sold count is part of the run, so it survives a save.
	var copy: RunState = RunState.from_dict(loop.state.to_dict())
	assert_int(copy.store_sold[item_id]).is_equal(1)


func test_a_save_from_before_limited_stock_loads_with_nothing_sold() -> void:
	var data: Dictionary = RunState.new(3).to_dict()
	data.erase("store_sold")
	var migrated: Dictionary = RunRecord.migrate_from_3({"checkpoint": data, "commands": []})
	var checkpoint: Dictionary = migrated["checkpoint"]
	assert_bool(RunState.from_dict(checkpoint).store_sold.is_empty()).is_true()


func test_plot_upgrades_enlarge_the_plot_up_to_their_limit_and_raise_resentment() -> void:
	var loop: RunLoop = _at_the_shops(14)
	var room: int = PlotSwap.capacity(loop.state, RunLoop.DEFAULT_PARAMS)
	var coupons: int = loop.state.coupons
	for step: int in UPGRADES.capacity_max:
		var before: int = loop.state.resentment
		assert_int(loop.player_upgrade(PlotUpgrades.CAPACITY)).is_equal(RunLoop.Reason.OK)
		assert_int(loop.state.resentment).is_greater(before)
		assert_int(PlotSwap.capacity(loop.state, RunLoop.DEFAULT_PARAMS)).is_equal(room + step + 1)
	assert_int(loop.state.coupons).is_equal(
		coupons - UPGRADES.capacity_cost * UPGRADES.capacity_max
	)
	assert_int(loop.player_upgrade(PlotUpgrades.CAPACITY)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.player_upgrade(PlotUpgrades.SWAPS)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.swap_bonus).is_equal(1)
	assert_int(loop.player_upgrade("nothing")).is_equal(RunLoop.Reason.ILLEGAL)


func test_market_commands_replay_from_a_save() -> void:
	var loop: RunLoop = _at_the_shops(15)
	var coupons: int = loop.state.coupons
	assert_int(loop.player_market_reroll()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_market_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_upgrade(PlotUpgrades.SWAPS)).is_equal(RunLoop.Reason.OK)
	assert_int(coupons).is_greater(loop.state.coupons)
	var record: Dictionary = loop.record.to_dict()
	# The checkpoint was marked at the Set's end, before the test handed out coupons.
	var checkpoint: Dictionary = record["checkpoint"]
	checkpoint["coupons"] = RICH
	var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.coupons).is_equal(loop.state.coupons)
	assert_array(resumed.state.inventory.cadres).is_equal(loop.state.inventory.cadres)
	assert_int(resumed.state.swap_bonus).is_equal(1)
	assert_int(resumed.state.resentment).is_equal(loop.state.resentment)
	assert_array(resumed.market.stock()).is_equal(loop.market.stock())


func _resentment_events(loop: RunLoop) -> int:
	var count: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.RESENTMENT:
			count += 1
	return count


func _is(item_id: String) -> Callable:
	return func(definition: ModifierDef) -> bool: return definition.id == item_id


func _costing(cost: int) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.id = "test_item"
	definition.cost = cost
	return definition


func test_a_private_cadre_from_the_market_is_counted_at_the_sets_end() -> void:
	var held: Array[String] = [MARKET_POOL.cadres[0].id, STORE_POOL.cadres[0].id]
	assert_int(Resentment.private_cadres(held, RunLoop.all_cadres())).is_equal(1)


func test_the_market_sells_cards_for_the_plot_the_same_for_the_same_seed() -> void:
	for seed_value: int in 60:
		var first: RunLoop = _at_the_shops(seed_value)
		var second: RunLoop = _at_the_shops(seed_value)
		assert_int(first.stall.count()).is_equal(UPGRADES.card_offers)
		for slot: int in first.stall.count():
			assert_int(first.stall.rank(slot)).is_equal(second.stall.rank(slot))
			assert_int(first.stall.suit(slot)).is_equal(second.stall.suit(slot))
			assert_array(UPGRADES.card_ranks).contains([first.stall.rank(slot)])


func test_a_bought_plot_card_enters_the_plot_and_raises_resentment() -> void:
	var loop: RunLoop = _at_the_shops(16)
	var rank: int = loop.stall.rank(0)
	var before: int = loop.state.resentment
	var coupons: int = loop.state.coupons
	var price: int = loop.stall.price(0)
	assert_int(loop.player_plot_card(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.inventory.plot.size()).is_equal(1)
	var card: CardInstance = loop.state.inventory.plot[0]
	assert_int(card.base_rank()).is_equal(rank)
	assert_int(card.id()).is_greater_equal(CardInstance.FIRST_PLOT_ID)
	assert_int(card.origin()).is_equal(CardInstance.Origin.PLOT)
	assert_int(loop.state.coupons).is_equal(coupons - price)
	assert_int(loop.state.resentment).is_greater(before)
	# Sold once, and refused without changing anything.
	var after: int = loop.state.resentment
	assert_int(loop.player_plot_card(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.state.resentment).is_equal(after)
	# The purchase replays from a save.
	var record: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = record["checkpoint"]
	checkpoint["coupons"] = RICH
	var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.inventory.plot.size()).is_equal(1)
	assert_int(resumed.state.inventory.plot[0].id()).is_equal(card.id())


func test_a_full_plot_takes_no_more_cards() -> void:
	var loop: RunLoop = _at_the_shops(17)
	var room: int = PlotSwap.capacity(loop.state, RunLoop.DEFAULT_PARAMS)
	for index: int in room:
		loop.state.inventory.plot.append(
			CardInstance.new(loop.state.take_plot_id(), 12, 0, CardInstance.Origin.PLOT)
		)
	assert_int(loop.stall.check_buy(0)).is_equal(PlotStall.Reason.PLOT_FULL)
	assert_int(loop.player_plot_card(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.state.inventory.plot.size()).is_equal(room)


func test_reeducation_can_exchange_for_a_private_cadre() -> void:
	var state: RunState = RunState.new(18)
	for definition: ModifierDef in STORE_POOL.cadres:
		state.inventory.cadres.append(definition.id)
	var change: PackedStringArray = Reeducation.change_cadre(
		state.inventory, RunLoop.all_cadres(), state.streams.stream(RandomStreams.EVENTS)
	)
	assert_int(change.size()).is_equal(2)
	assert_bool(MARKET_POOL.cadres.any(_is(change[1]))).is_true()


func test_a_reroll_is_only_offered_when_it_can_change_the_counter() -> void:
	var loop: RunLoop = _at_the_shops(19)
	# The state store has as many Cadres as slots, so a reroll would only reorder them.
	assert_int(STORE_POOL.cadres.size()).is_less_equal(STORE.slots)
	assert_bool(loop.shop.reroll_changes()).is_false()
	assert_bool(loop.market.reroll_changes()).is_true()


func test_a_save_from_the_middle_of_phase_4_gains_every_missing_field() -> void:
	var data: Dictionary = RunState.new(3).to_dict()
	for field: String in ["store_sold", "styles", "boss_family", "swap_bonus", "memory", "risen"]:
		data.erase(field)
	var record: Dictionary = {"checkpoint": data, "commands": []}
	assert_bool(RunRecord.is_valid(record)).is_false()
	assert_bool(RunRecord.is_valid(RunRecord.migrate_from_3(record))).is_true()

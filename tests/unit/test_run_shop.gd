extends GdUnitTestSuite
## The state store's stock is deterministic per seed, respects ownership and rarity, and
## buying and rerolling spend coupons by the rules.

const POOL: CadrePool = preload("res://data/run/cadre_pool.tres")
const PARAMS: ShopParams = preload("res://data/run/default_shop.tres")


func _shop(seed_value: int, coupons: int = 0) -> RunShop:
	var state: RunState = RunState.new(seed_value)
	state.coupons = coupons
	var shop: RunShop = RunShop.new(state, PARAMS, POOL.cadres)
	shop.open()
	return shop


func test_stock_is_the_same_for_the_same_seed() -> void:
	for seed_value: int in range(100):
		assert_array(_shop(seed_value).stock()).is_equal(_shop(seed_value).stock())


func test_stock_differs_across_seeds() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in range(50):
		seen[",".join(_shop(seed_value).stock())] = true
	assert_int(seen.size()).is_greater(1)


func test_stock_has_distinct_unowned_cadres() -> void:
	var state: RunState = RunState.new(7)
	state.inventory.cadres.append(POOL.cadres[0].id)
	var shop: RunShop = RunShop.new(state, PARAMS, POOL.cadres)
	shop.open()
	var stock: Array[String] = shop.stock()
	assert_int(stock.size()).is_equal(mini(PARAMS.slots, POOL.cadres.size() - 1))
	assert_array(stock).not_contains([POOL.cadres[0].id])
	var unique: Dictionary[String, bool] = {}
	for modifier_id: String in stock:
		unique[modifier_id] = true
	assert_int(unique.size()).is_equal(stock.size())


func test_common_cadres_show_up_more_than_rare_ones() -> void:
	var by_rarity: Array[int] = [0, 0, 0]
	var rarity_of: Dictionary[String, int] = {}
	for definition: ModifierDef in POOL.cadres:
		rarity_of[definition.id] = definition.rarity
	for seed_value: int in range(2000):
		var drawn: Array[String] = RunShop.draw(
			POOL.cadres,
			1,
			[],
			PARAMS.rarity_weights,
			RunState.new(seed_value).streams.stream(RandomStreams.SHOP)
		)
		by_rarity[rarity_of[drawn[0]]] += 1
	var common_each: float = by_rarity[0] / float(_count(0))
	var uncommon_each: float = by_rarity[1] / float(_count(1))
	assert_float(common_each).is_greater(uncommon_each)


func test_buying_spends_coupons_and_takes_the_cadre() -> void:
	var state: RunState = RunState.new(11)
	state.coupons = 100
	var shop: RunShop = RunShop.new(state, PARAMS, POOL.cadres)
	shop.open()
	var bought: String = shop.stock()[0]
	var price: int = shop.price(0)
	assert_int(shop.buy(0)).is_equal(RunShop.Reason.OK)
	assert_array(shop.stock()).contains([RunShop.SOLD])
	assert_int(shop.buy(0)).is_equal(RunShop.Reason.SOLD_OUT)
	assert_int(state.coupons).is_equal(100 - price)
	assert_array(state.inventory.cadres).contains_exactly([bought])


func test_a_purchase_needs_coupons_and_a_slot() -> void:
	assert_int(_shop(12, 0).buy(0)).is_equal(RunShop.Reason.TOO_POOR)
	assert_int(_shop(12, 100).buy(PARAMS.slots)).is_equal(RunShop.Reason.NO_SUCH_SLOT)
	var state: RunState = RunState.new(12)
	state.coupons = 100
	for index: int in PARAMS.cadre_slots:
		state.inventory.cadres.append("held_%d" % index)
	var full: RunShop = RunShop.new(state, PARAMS, POOL.cadres)
	full.open()
	assert_int(full.buy(0)).is_equal(RunShop.Reason.CADRES_FULL)


func test_rerolls_cost_more_each_time() -> void:
	var shop: RunShop = _shop(13, 100)
	var first: int = shop.reroll_price()
	assert_int(shop.reroll()).is_equal(RunShop.Reason.OK)
	assert_int(shop.reroll_price()).is_equal(first + PARAMS.reroll_step)
	assert_int(_shop(13, 0).reroll()).is_equal(RunShop.Reason.TOO_POOR)


func _count(rarity: int) -> int:
	return (
		POOL
		. cadres
		. filter(func(definition: ModifierDef) -> bool: return definition.rarity == rarity)
		. size()
	)

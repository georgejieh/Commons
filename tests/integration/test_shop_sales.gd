extends GdUnitTestSuite
## Selling Cadres and Campaigns back at either shop (ADR 0040, the owner's playtest of
## 2026-11-24): a sale pays sell_percent of the item's price at that counter now, rounded
## down and never under one coupon; the item leaves for good with its saved state, frees
## its place at once, is not offered again that visit, gives back nothing its purchase
## changed and changes no meter; a sale is refused away from the shops, for an item not
## held, and for a Cadre a debuff holds; and a save replays every sale.

const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const RICH: int = 1000


func _at_the_shops(seed_value: int, coupons: int = RICH) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = coupons
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


func _cost(cadre_id: String) -> int:
	for definition: ModifierDef in RunLoop.all_cadres():
		if definition.id == cadre_id:
			return definition.cost
	return -1


func test_the_sale_share_lives_in_data() -> void:
	assert_int(STORE.sell_percent).is_equal(50)
	assert_int(MARKET.sell_percent).is_equal(50)


func test_a_sale_pays_half_the_price_at_that_counter_rounded_down_and_never_nothing() -> void:
	var state: RunState = RunState.new(1)
	for cost: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var at_store: int = ceili(cost * STORE.price_percent / 100.0)
		var at_market: int = ceili(cost * MARKET.price_percent / 100.0)
		assert_int(RunShop.sale_of(state, STORE, cost)).is_equal(
			maxi(1, at_store * STORE.sell_percent / 100)
		)
		assert_int(RunShop.sale_of(state, MARKET, cost)).is_equal(
			maxi(1, at_market * MARKET.sell_percent / 100)
		)
	assert_int(RunShop.sale_of(state, STORE, 1)).is_equal(1)


func test_selling_a_cadre_pays_frees_its_place_and_forgets_it() -> void:
	var loop: RunLoop = _at_the_shops(21)
	assert_int(loop.player_buy(0)).is_equal(RunLoop.Reason.OK)
	var held: Array[String] = loop.state.inventory.cadres.duplicate()
	var index: int = held.size() - 1
	var cadre_id: String = held[index]
	loop.state.cadre_memos.entry(cadre_id).put("count", 3)
	var coupons: int = loop.state.coupons
	var meters: Array[int] = [loop.state.resentment, loop.state.famine, loop.state.denunciation]
	var paid: int = loop.visit.shop.sale_price(_cost(cadre_id))
	assert_int(loop.player_sell_cadre(index)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons + paid)
	assert_array(loop.state.inventory.cadres).not_contains([cadre_id])
	assert_int(loop.state.inventory.cadres.size()).is_equal(held.size() - 1)
	assert_bool(loop.state.cadre_memos.has(cadre_id)).is_false()
	assert_array([loop.state.resentment, loop.state.famine, loop.state.denunciation]).is_equal(
		meters
	)
	var sold: RunEvent = loop.events()[-1]
	assert_int(sold.type).is_equal(RunEvent.Type.CADRE_SOLD)
	assert_int(sold.value).is_equal(paid)
	assert_str(sold.text).is_equal(cadre_id)
	# The state store may stock it again from the next visit, not in this one.
	assert_int(loop.visit.shop.left(cadre_id)).is_not_equal(0)
	for _reroll: int in 6:
		assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(loop.visit.shop.stock()).not_contains([cadre_id])


func test_a_sale_at_the_market_pays_the_markets_price_and_raises_no_resentment() -> void:
	var loop: RunLoop = _at_the_shops(22)
	assert_int(loop.player_market_buy(0, Ranks.SEVEN)).is_equal(RunLoop.Reason.OK)
	var index: int = loop.state.inventory.cadres.size() - 1
	var cadre_id: String = loop.state.inventory.cadres[index]
	var resentment: int = loop.state.resentment
	var coupons: int = loop.state.coupons
	var paid: int = RunShop.sale_of(loop.state, MARKET, _cost(cadre_id))
	assert_int(loop.player_sell_cadre(index, true)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons + paid)
	assert_int(loop.state.resentment).is_equal(resentment)
	for _reroll: int in 6:
		assert_int(loop.player_market_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(loop.visit.market.stock()).not_contains([cadre_id])


func test_a_full_board_has_room_again_the_moment_a_cadre_is_sold() -> void:
	var loop: RunLoop = _at_the_shops(23)
	var spare: Array[String] = []
	for definition: ModifierDef in RunLoop.all_cadres():
		if not loop.state.inventory.cadres.has(definition.id):
			spare.append(definition.id)
	while loop.state.inventory.cadres.size() < RunReforms.cadre_slots(loop.state):
		loop.state.inventory.cadres.append(spare.pop_back())
	assert_int(loop.visit.shop.check_buy(0)).is_equal(RunShop.Reason.CADRES_FULL)
	assert_int(loop.player_sell_cadre(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.visit.shop.check_buy(0)).is_equal(RunShop.Reason.OK)


func test_the_households_first_cadre_sells_like_any_other() -> void:
	var loop: RunLoop = _at_the_shops(24)
	if loop.state.inventory.cadres.is_empty():
		loop.state.inventory.cadres.append(RunLoop.all_cadres()[0].id)
	var first: String = loop.state.inventory.cadres[0]
	assert_int(loop.player_sell_cadre(0)).is_equal(RunLoop.Reason.OK)
	assert_array(loop.state.inventory.cadres).not_contains([first])


func test_a_refused_sale_changes_nothing() -> void:
	var loop: RunLoop = _at_the_shops(25)
	var before: Dictionary = loop.state.to_dict()
	assert_int(loop.player_sell_cadre(-1)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.player_sell_cadre(99)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.player_sell_campaign(99)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_dict(loop.state.to_dict()).is_equal(before)
	# A Cadre a debuff holds stays; the reason says so.
	if loop.state.inventory.cadres.is_empty():
		loop.state.inventory.cadres.append(RunLoop.all_cadres()[0].id)
	var held: String = loop.state.inventory.cadres[0]
	var definition: ModifierDef = null
	for known: ModifierDef in RunLoop.all_cadres():
		if known.id == held:
			definition = known
	var bound: Array[String] = [held]
	assert_int(loop.visit.shop.check_sell(0, definition, bound)).is_equal(
		RunShop.Reason.CADRE_BOUND
	)
	assert_int(loop.visit.shop.sell(0, definition, bound)).is_equal(RunShop.Reason.CADRE_BOUND)
	assert_array(loop.state.inventory.cadres).contains([held])


func test_nothing_is_sold_at_the_table() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(26), RunScript.bots(), SetConfig.new())
	loop.start_set()
	loop.state.inventory.cadres.append(RunLoop.all_cadres()[0].id)
	loop.state.inventory.consumables.append(RunCampaigns.all()[0].id)
	assert_int(loop.player_sell_cadre(0)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.player_sell_campaign(0)).is_equal(RunLoop.Reason.NOT_AWAITED)


func test_selling_a_campaign_pays_frees_its_place_and_keeps_it_off_the_counter() -> void:
	var loop: RunLoop = _at_the_shops(27)
	var campaign: CampaignDef = RunCampaigns.all()[0]
	while loop.state.inventory.consumables.size() < RunReforms.campaign_slots(loop.state):
		loop.state.inventory.consumables.append(campaign.id)
	assert_int(loop.visit.shop.campaigns.check(0)).is_equal(RunShop.Reason.CAMPAIGNS_FULL)
	var coupons: int = loop.state.coupons
	var paid: int = RunShop.sale_of(loop.state, STORE, campaign.cost)
	var held: int = loop.state.inventory.consumables.size()
	assert_int(loop.player_sell_campaign(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons + paid)
	assert_int(loop.state.inventory.consumables.size()).is_equal(held - 1)
	assert_int(loop.visit.shop.campaigns.check(0)).is_not_equal(RunShop.Reason.CAMPAIGNS_FULL)
	var sold: RunEvent = loop.events()[-1]
	assert_int(sold.type).is_equal(RunEvent.Type.CAMPAIGN_SOLD)
	assert_int(sold.value).is_equal(paid)
	for _reroll: int in 6:
		assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(loop.visit.shop.campaigns.stock()).not_contains([campaign.id])


func test_sales_replay_from_a_save_and_an_older_save_still_loads() -> void:
	var loop: RunLoop = _at_the_shops(28)
	# A record with no sale in it, as every save before ADR 0040, loads as it did.
	var older: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = older["checkpoint"]
	checkpoint["coupons"] = RICH
	assert_bool(RunRecordCheck.is_valid(older)).is_true()
	assert_object(RunRecord.resume(older, RunScript.bots(), SetConfig.new())).is_not_null()
	assert_int(loop.player_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_sell_cadre(loop.state.inventory.cadres.size() - 1)).is_equal(
		RunLoop.Reason.OK
	)
	assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
	var record: Dictionary = loop.record.to_dict()
	var saved: Dictionary = record["checkpoint"]
	saved["coupons"] = RICH
	assert_bool(RunRecordCheck.is_valid(record)).is_true()
	var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.coupons).is_equal(loop.state.coupons)
	assert_array(resumed.state.inventory.cadres).is_equal(loop.state.inventory.cadres)
	assert_array(resumed.visit.shop.stock()).is_equal(loop.visit.shop.stock())
	assert_dict(resumed.state.store_sold).is_equal(loop.state.store_sold)


## A loop at the shops holding a copy of the Campaign the counter offers in slot 0, as a
## player who bought it on an earlier visit would.
func _holding_the_shelfs_campaign(seed_value: int, at_market: bool) -> RunLoop:
	var probe: RunLoop = _at_the_shops(seed_value)
	var counter: CampaignCounter = (
		probe.visit.market.campaigns if at_market else probe.visit.shop.campaigns
	)
	var campaign_id: String = counter.stock()[0]
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = RICH
	loop.state.inventory.consumables.append(campaign_id)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	var shelf: CampaignCounter = (
		loop.visit.market.campaigns if at_market else loop.visit.shop.campaigns
	)
	assert_str(shelf.stock()[0]).is_equal(campaign_id)
	return loop


## The loop's record, its checkpoint given the coupons and Campaigns the test handed it.
func _record_of(loop: RunLoop, campaign_id: String) -> Dictionary:
	var record: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = record["checkpoint"]
	checkpoint["coupons"] = RICH
	var held: Array = checkpoint["inventory"]["consumables"]
	if not held.has(campaign_id):
		held.append(campaign_id)
	return record


## ADR 0040: the Campaign just sold cannot be bought straight back from the copy already
## on the shelf, at either counter, and the save replays the sale and the refusal alike.
func test_a_sold_campaign_cannot_be_bought_back_from_the_shelf_that_visit() -> void:
	for at_market: bool in [false, true]:
		var loop: RunLoop = _holding_the_shelfs_campaign(29, at_market)
		var shelf: CampaignCounter = (
			loop.visit.market.campaigns if at_market else loop.visit.shop.campaigns
		)
		var campaign_id: String = shelf.stock()[0]
		var index: int = loop.state.inventory.consumables.rfind(campaign_id)
		assert_int(shelf.check(0)).is_equal(RunShop.Reason.OK)
		assert_int(loop.player_sell_campaign(index, at_market)).is_equal(RunLoop.Reason.OK)
		for counter: CampaignCounter in [loop.visit.shop.campaigns, loop.visit.market.campaigns]:
			for slot: int in counter.stock().size():
				if counter.stock()[slot] == campaign_id:
					assert_int(counter.check(slot)).is_equal(RunShop.Reason.SOLD_BACK)
		var after_sale: Dictionary = loop.state.to_dict()
		var bought: RunLoop.Reason = (
			loop.player_market_campaign(0) if at_market else loop.player_campaign_buy(0)
		)
		assert_int(bought).is_equal(RunLoop.Reason.ILLEGAL)
		assert_dict(loop.state.to_dict()).is_equal(after_sale)
		var record: Dictionary = _record_of(loop, campaign_id)
		var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
		assert_object(resumed).is_not_null()
		assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())
		var again: CampaignCounter = (
			resumed.visit.market.campaigns if at_market else resumed.visit.shop.campaigns
		)
		assert_int(again.check(0)).is_equal(RunShop.Reason.SOLD_BACK)


## The same for a Cadre: one sold back cannot be bought from a slot of either counter that
## offers it that visit.
func test_a_sold_cadre_cannot_be_bought_back_from_either_shelf_that_visit() -> void:
	for at_market: bool in [false, true]:
		var loop: RunLoop = _at_the_shops(30)
		var counter: RunShop = loop.visit.market if at_market else loop.visit.shop
		var cadre_id: String = counter.stock()[0]
		loop.state.inventory.cadres.append(cadre_id)
		var index: int = loop.state.inventory.cadres.size() - 1
		assert_int(loop.player_sell_cadre(index, at_market)).is_equal(RunLoop.Reason.OK)
		assert_int(counter.check_buy(0)).is_equal(RunShop.Reason.SOLD_BACK)
		var before: Dictionary = loop.state.to_dict()
		var bought: RunLoop.Reason = (
			loop.player_market_buy(0, Ranks.SEVEN) if at_market else loop.player_buy(0)
		)
		assert_int(bought).is_equal(RunLoop.Reason.ILLEGAL)
		assert_dict(loop.state.to_dict()).is_equal(before)


## A Campaign sold back cannot be kept from an envelope opened after the sale that visit.
func test_an_envelope_will_not_hand_back_a_campaign_sold_that_visit() -> void:
	var loop: RunLoop = _at_the_shops(31)
	var counter: EnvelopeCounter = loop.visit.shop.envelopes
	var campaign_id: String = RunCampaigns.all()[0].id
	loop.visit.shop.campaigns.withheld.append(campaign_id)
	var item: EnvelopeItem = EnvelopeItem.new(EnvelopeDef.Content.CAMPAIGN, campaign_id)
	counter.set("_opened", EnvelopeDef.new())
	counter.set("_items", [item] as Array[EnvelopeItem])
	assert_int(counter.check_pick(0)).is_equal(RunShop.Reason.SOLD_BACK)
	assert_int(counter.pick(0, RunLoop.PLAYER)).is_equal(RunShop.Reason.SOLD_BACK)
	assert_array(loop.state.inventory.consumables).not_contains([campaign_id])
	loop.visit.shop.campaigns.withheld.clear()
	assert_int(counter.check_pick(0)).is_not_equal(RunShop.Reason.SOLD_BACK)

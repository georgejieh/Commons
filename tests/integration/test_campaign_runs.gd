extends GdUnitTestSuite
## Campaigns across a run (ADR 0021): each shop offers its own pool's Campaigns, the
## same for the same seed, redrawn by a reroll and refused once the player holds as many
## as they can; a Set with Campaign uses replays from its record to the same state, and a
## save taken right after a use resumes there. Red Ink is back on the black market.

const STORE_POOL: CampaignPool = preload("res://data/run/campaign_pool.tres")
const MARKET_POOL: CampaignPool = preload("res://data/run/market_campaign_pool.tres")
const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const CADRE_MARKET: CadrePool = preload("res://data/run/market_pool.tres")
const SEEDS: int = 30
const RICH: int = 1000
## How often, out of 100 player decisions, a replayed Set tries a Campaign.
const TRY_PERCENT: int = 35


func _at_the_shops(seed_value: int) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = RICH
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


func _in_pool(pool: CampaignPool, campaign_id: String) -> bool:
	for campaign: CampaignDef in pool.campaigns:
		if campaign.id == campaign_id:
			return true
	return false


func test_the_pools_hold_adr_0021s_campaigns_by_tag() -> void:
	# ADR 0021's five, ADR 0029's Model Worker, ADR 0032's two and ADR 0041's three, all
	# collective, and ADR 0021's three and ADR 0032's False Report, all private.
	assert_int(STORE_POOL.campaigns.size()).is_equal(11)
	assert_int(MARKET_POOL.campaigns.size()).is_equal(4)
	for campaign: CampaignDef in STORE_POOL.campaigns:
		assert_int(campaign.tag).is_equal(ModifierDef.Tag.COLLECTIVE)
	for campaign: CampaignDef in MARKET_POOL.campaigns:
		assert_int(campaign.tag).is_equal(ModifierDef.Tag.PRIVATE)
	var red_ink: bool = CADRE_MARKET.cadres.any(
		func(cadre: ModifierDef) -> bool: return cadre.id == "red_ink"
	)
	assert_bool(red_ink).is_true()


func test_each_shop_offers_its_campaign_the_same_for_the_same_seed() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: RunLoop = _at_the_shops(seed_value)
		var second: RunLoop = _at_the_shops(seed_value)
		var store: Array[String] = first.shop.campaigns.stock()
		assert_int(store.size()).is_equal(STORE.campaign_offers)
		assert_bool(_in_pool(STORE_POOL, store[0])).is_true()
		assert_bool(_in_pool(MARKET_POOL, first.market.campaigns.stock()[0])).is_true()
		assert_array(store).is_equal(second.shop.campaigns.stock())
		assert_array(first.market.campaigns.stock()).is_equal(second.market.campaigns.stock())
		# A reroll redraws, as repeatably.
		assert_int(first.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_int(second.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_array(first.shop.campaigns.stock()).is_equal(second.shop.campaigns.stock())
		seen["%s>%s" % [store[0], first.shop.campaigns.stock()[0]]] = true
	assert_int(seen.size()).is_greater(4)


func test_buying_fills_the_slots_and_a_third_is_refused() -> void:
	var loop: RunLoop = _at_the_shops(5)
	var coupons: int = loop.state.coupons
	var price: int = loop.shop.campaigns.price(0)
	var bought: String = loop.shop.campaigns.stock()[0]
	assert_int(loop.player_campaign_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons - price)
	assert_array(loop.state.inventory.consumables).is_equal([bought])
	assert_int(loop.player_campaign_buy(0)).is_equal(RunLoop.Reason.ILLEGAL)
	var resentment: int = loop.state.resentment
	assert_int(loop.player_market_campaign(0)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.resentment).is_greater(resentment)
	assert_int(loop.state.inventory.consumables.size()).is_equal(STORE.campaign_slots)
	assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.shop.campaigns.check(0)).is_equal(RunShop.Reason.CAMPAIGNS_FULL)
	var before: Dictionary = loop.state.to_dict()
	assert_int(loop.player_campaign_buy(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_dict(loop.state.to_dict()).is_equal(before)


func test_the_market_charges_its_percent_rounded_up() -> void:
	var loop: RunLoop = _at_the_shops(9)
	var offered: String = loop.market.campaigns.stock()[0]
	var cost: int = RunDefinitions.campaigns[offered].cost
	assert_int(MARKET.price_percent).is_greater(100)
	var dear: int = ceili(cost * MARKET.price_percent / 100.0)
	assert_int(loop.market.campaigns.price(0)).is_equal(dear)


## Plays the player's seat, sometimes trying a held Campaign on random cards first. Every
## command goes through the loop, so the record holds it.
func _play_with_campaigns(
	loop: RunLoop, stream: RandomStream, stop_after_use: bool, stop_round: int = 99
) -> bool:
	var script: RunScript = RunScript.new()
	for _step: int in 600:
		if loop.state.round_index >= stop_round and _mid_round(loop):
			return false
		if _try_campaign(loop, stream) and stop_after_use:
			return true
		if not script.act(loop):
			return false
	return false


func _mid_round(loop: RunLoop) -> bool:
	var round_state: RoundState = loop.round_state()
	return round_state != null and round_state.public_view().history.size() > 4


func _try_campaign(loop: RunLoop, stream: RandomStream) -> bool:
	var held: Array[String] = loop.state.inventory.consumables
	if held.is_empty() or stream.next_int(0, 99) >= TRY_PERCENT:
		return false
	var slot: int = stream.next_int(0, held.size() - 1)
	var cards: Vector2i = Vector2i(
		RunDefinitions.campaigns[held[slot]].min_cards,
		RunDefinitions.campaigns[held[slot]].max_cards
	)
	var hand: Array[CardInstance] = loop.player_cards()
	var ids: Array[int] = []
	var count: int = stream.next_int(cards.x, cards.y)
	while ids.size() < mini(count, hand.size()):
		var card_id: int = hand[stream.next_int(0, hand.size() - 1)].id()
		if not ids.has(card_id):
			ids.append(card_id)
	return loop.player_campaign(slot, ids) == RunLoop.Reason.OK


func _all_held() -> Array[String]:
	var ids: Array[String] = []
	for campaign: CampaignDef in RunCampaigns.all():
		ids.append(campaign.id)
	return ids


func _loop(seed_value: int, held: Array[String]) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.inventory.consumables.assign(held)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


func _log(loop: RunLoop) -> PackedStringArray:
	var lines: PackedStringArray = []
	for event: RunEvent in loop.events():
		lines.append(event.describe())
	return lines


## Every Campaign held at once (more than the slots allow, to try them all), used at
## random moments through the Set's first rounds: replaying the Set's record rebuilds the
## same state and the same log, mid-round.
func test_a_set_with_campaign_uses_replays_to_the_same_state() -> void:
	var used: int = 0
	for seed_value: int in range(1, 9):
		var loop: RunLoop = _loop(seed_value, _all_held())
		_play_with_campaigns(loop, RandomStream.new(seed_value), false, 1)
		assert_int(loop.awaiting()).is_not_equal(RunLoop.Awaiting.SET_OVER)
		used += _all_held().size() - loop.state.inventory.consumables.size()
		var resumed: RunLoop = RunRecord.resume(loop.record.to_dict(), RunScript.bots())
		assert_object(resumed).is_not_null()
		assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())
		assert_array(Array(_log(resumed))).is_equal(Array(_log(loop)))
		assert_int(resumed.awaiting()).is_equal(loop.awaiting())
	assert_int(used).is_greater(8)


## A save taken right after a use, mid-round, resumes at the same moment with the
## round's Campaign flags rebuilt, and plays on to the same end.
func test_a_save_right_after_a_use_resumes_there() -> void:
	var checked: int = 0
	for seed_value: int in range(1, 12):
		var loop: RunLoop = _loop(seed_value, _all_held())
		if not _play_with_campaigns(loop, RandomStream.new(seed_value), true):
			continue
		var saved: Dictionary = JSON.parse_string(JSON.stringify(loop.record.to_dict()))
		var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots())
		assert_object(resumed).is_not_null()
		assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())
		assert_int(resumed.awaiting()).is_equal(loop.awaiting())
		var flags: CampaignRound = loop.campaigns.flags
		var rebuilt: CampaignRound = resumed.campaigns.flags
		assert_bool(rebuilt.letter_armed).is_equal(flags.letter_armed)
		assert_bool(rebuilt.staked).is_equal(flags.staked)
		assert_str(rebuilt.lifted).is_equal(flags.lifted)
		RunScript.new().play_until_set_over(loop)
		RunScript.new().play_until_set_over(resumed)
		assert_dict(resumed.state.to_dict()).is_equal(loop.state.to_dict())
		checked += 1
	assert_int(checked).is_greater(3)

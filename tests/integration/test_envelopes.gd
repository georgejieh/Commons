extends GdUnitTestSuite
## Envelopes (ADR 0021): the state store offers a Directive or a Campaign envelope a visit
## and the black market a Parcel, drawn last on the shop stream; buying one opens it with
## contents that are the same for the same seed and shift no later draw; keeping an item
## issues it, holds it or plants it, refusals change nothing, and while one is open every
## other shop command waits. All of it saves mid-opening and replays exactly.

const STORE: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET: ShopParams = preload("res://data/run/black_market.tres")
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const SEEDS: int = 24
const RICH: int = 1000
const KINDS: Array[String] = ["directive_envelope", "campaign_envelope", "deck_envelope"]


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


## Puts one kind on the state store's counter, as only tests do.
func _offer(loop: RunLoop, envelope_id: String) -> void:
	var stock: Array[String] = [envelope_id]
	loop.shop.envelopes.set("_stock", stock)


func _ids(items: Array[EnvelopeItem]) -> Array[String]:
	var ids: Array[String] = []
	for item: EnvelopeItem in items:
		ids.append("%d:%s:%d:%d" % [item.content, item.item_id, item.rank, item.suit])
	return ids


func _saved(loop: RunLoop) -> Dictionary:
	return JSON.parse_string(JSON.stringify(loop.record.to_dict()))


func _same_state(first: RunLoop, second: RunLoop) -> void:
	assert_str(JSON.stringify(second.state.to_dict())).is_equal(
		JSON.stringify(first.state.to_dict())
	)


func test_each_shop_offers_its_envelopes_the_same_for_the_same_seed() -> void:
	assert_int(STORE.envelope_offers).is_equal(1)
	assert_int(MARKET.envelope_offers).is_equal(1)
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: RunLoop = _at_the_shops(seed_value)
		var second: RunLoop = _at_the_shops(seed_value)
		var offer: Array[String] = first.shop.envelopes.stock()
		assert_int(offer.size()).is_equal(1)
		assert_bool(KINDS.has(offer[0])).is_true()
		assert_array(offer).is_equal(second.shop.envelopes.stock())
		assert_array(first.market.envelopes.stock()).is_equal(["parcel"])
		assert_int(first.shop.envelopes.price(0)).is_equal(4)
		var dear: int = ceili(4 * MARKET.price_percent / 100.0)
		assert_int(first.market.envelopes.price(0)).is_equal(dear)
		first.player_reroll()
		second.player_reroll()
		assert_array(first.shop.envelopes.stock()).is_equal(second.shop.envelopes.stock())
		seen[offer[0]] = true
	assert_int(seen.size()).is_equal(KINDS.size())


## The offer comes last on the shop stream and the contents on a stream of their own, so
## every other draw a seed makes in the visit is as it was, rerolls included.
func test_envelopes_leave_every_other_draw_alone() -> void:
	for seed_value: int in 6:
		var loop: RunLoop = _at_the_shops(seed_value)
		var bare_state: RunState = RunState.new(seed_value)
		var bare: RunLoop = RunLoop.new(bare_state, RunScript.bots(), SetConfig.new())
		var none: ShopParams = STORE.duplicate()
		none.envelope_offers = 0
		bare.shop.envelopes = EnvelopeCounter.new(bare_state, none, [], [], RunDefaults.PARAMS)
		bare.start_set()
		RunScript.new().play_until_set_over(bare)
		bare.state.coupons = RICH
		bare.open_shop()
		_same_stock(bare, loop)
		# Opening an envelope before a reroll leaves the reroll's stock as it would be.
		assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
		assert_int(loop.player_envelope_pick(EnvelopeCounter.NOTHING)).is_equal(RunLoop.Reason.OK)
		var twin: RunLoop = _at_the_shops(seed_value)
		assert_int(loop.player_reroll()).is_equal(RunLoop.Reason.OK)
		assert_int(twin.player_reroll()).is_equal(RunLoop.Reason.OK)
		_same_stock(twin, loop)
		# Once bought, the place stays sold through a reroll.
		assert_array(loop.shop.envelopes.stock()).is_equal([EnvelopeCounter.SOLD])


func _same_stock(expected: RunLoop, loop: RunLoop) -> void:
	assert_array(loop.shop.stock()).is_equal(expected.shop.stock())
	assert_array(loop.market.stock()).is_equal(expected.market.stock())
	assert_array(loop.shop.directive_stock()).is_equal(expected.shop.directive_stock())
	assert_array(loop.shop.campaigns.stock()).is_equal(expected.shop.campaigns.stock())
	assert_array(loop.market.campaigns.stock()).is_equal(expected.market.campaigns.stock())
	assert_array(loop.shop.reforms.stock()).is_equal(expected.shop.reforms.stock())
	for slot: int in loop.stall.offers.count():
		assert_int(loop.stall.offers.rank(slot)).is_equal(expected.stall.offers.rank(slot))
		assert_int(loop.stall.offers.suit(slot)).is_equal(expected.stall.offers.suit(slot))


func test_buying_opens_the_envelope_with_the_same_contents_for_a_seed() -> void:
	for seed_value: int in 8:
		var loop: RunLoop = _at_the_shops(seed_value)
		var twin: RunLoop = _at_the_shops(seed_value)
		var price: int = loop.shop.envelopes.price(0)
		assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
		assert_int(twin.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
		assert_int(loop.state.coupons).is_equal(RICH - price)
		assert_dict(loop.record.commands[-1]).is_equal({"type": "envelope_buy", "slot": 0})
		assert_object(loop.open_envelope()).is_same(loop.shop.envelopes)
		var items: Array[EnvelopeItem] = loop.shop.envelopes.items()
		assert_int(items.size()).is_equal(3)
		assert_array(_ids(items)).is_equal(_ids(twin.shop.envelopes.items()))
		# No item twice.
		var ids: Array[String] = _ids(items)
		for index: int in ids.size():
			assert_int(ids.count(ids[index])).is_equal(1)
		var envelope: EnvelopeDef = loop.shop.envelopes.definition(loop.shop.envelopes.opened_id())
		for item: EnvelopeItem in items:
			assert_bool(envelope.contents.has(item.content)).is_true()


func test_too_few_coupons_or_nothing_to_show_refuses_the_envelope() -> void:
	var loop: RunLoop = _at_the_shops(3)
	loop.state.coupons = loop.shop.envelopes.price(0) - 1
	var commands: int = loop.record.commands.size()
	assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_object(loop.open_envelope()).is_null()
	assert_int(loop.record.commands.size()).is_equal(commands)
	assert_int(loop.player_envelope_buy(4)).is_equal(RunLoop.Reason.ILLEGAL)
	# With every hand type at the top level the Directive envelope has nothing to show.
	for seed_value: int in 10:
		var maxed: RunLoop = _at_the_shops(seed_value)
		for type: int in range(1, Pattern.Type.size()):
			while not maxed.state.hand_levels.is_max(type as Pattern.Type):
				maxed.state.hand_levels.raise(type as Pattern.Type)
		maxed.shop.envelopes.clear()
		maxed.shop.envelopes.draw()
		# The Campaign envelope and the Requisition are left to draw from (ADR 0042).
		assert_array(maxed.shop.envelopes.stock()).not_contains(["directive_envelope"])
		assert_bool(maxed.shop.envelopes.reroll_changes()).is_true()
		_offer(maxed, "directive_envelope")
		assert_int(maxed.player_envelope_buy(0)).is_equal(RunLoop.Reason.ILLEGAL)


func test_while_open_every_other_shop_command_waits() -> void:
	var loop: RunLoop = _at_the_shops(5)
	loop.state.inventory.consumables.assign(["grain_loan"])
	loop.state.inventory.cadres.assign(["rehabilitation"])
	assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
	# A black-market Cadre that needs a rank is refused as every other command is, rank or not.
	var ranked: Array[String] = ["planned_allocation"]
	loop.market.set("_stock", ranked)
	var before: String = JSON.stringify(loop.state.to_dict())
	var commands: int = loop.record.commands.size()
	var refused: Array[Callable] = [
		loop.player_market_buy.bind(0, Ranks.INVALID),
		loop.player_buy.bind(0),
		loop.player_reroll,
		loop.player_directive.bind(0),
		loop.player_campaign_buy.bind(0),
		loop.player_reform.bind(0),
		loop.player_market_buy.bind(0),
		loop.player_market_reroll,
		loop.player_market_campaign.bind(0),
		loop.player_upgrade.bind(PlotUpgrades.KINDS[0]),
		loop.player_plot_card.bind(0),
		loop.player_market_envelope.bind(0),
		loop.player_envelope_buy.bind(0),
		loop.player_campaign.bind(0, [] as Array[int]),
		loop.player_sell_cadre.bind(0),
		loop.player_sell_cadre.bind(0, true),
		loop.player_sell_campaign.bind(0),
		loop.player_sell_campaign.bind(0, true),
		loop.player_mark_card.bind(0),
		loop.player_mark_card.bind(0, true),
		loop.player_deck_card.bind(0, 0),
		loop.next_set,
		loop.leave_store,
	]
	for command: Callable in refused:
		assert_int(command.call()).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_str(JSON.stringify(loop.state.to_dict())).is_equal(before)
	assert_int(loop.record.commands.size()).is_equal(commands)
	# A pick out of range is refused and leaves it open.
	assert_int(loop.player_envelope_pick(9)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_object(loop.open_envelope()).is_not_null()
	assert_int(loop.player_envelope_pick(EnvelopeCounter.NOTHING)).is_equal(RunLoop.Reason.OK)
	assert_dict(loop.record.commands[-1]).is_equal({"type": "envelope_pick", "index": -1})
	assert_object(loop.open_envelope()).is_null()
	assert_int(loop.player_envelope_pick(EnvelopeCounter.NOTHING)).is_equal(
		RunLoop.Reason.NOT_AWAITED
	)
	assert_int(loop.player_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_envelope_pick(0)).is_equal(RunLoop.Reason.NOT_AWAITED)


func test_keeping_a_directive_issues_it_as_the_counter_does() -> void:
	var loop: RunLoop = _at_the_shops(6)
	_offer(loop, "directive_envelope")
	assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
	var items: Array[EnvelopeItem] = loop.shop.envelopes.items()
	var directive: DirectiveDef = null
	for candidate: DirectiveDef in RunPools.DIRECTIVES.directives:
		if candidate.id == items[1].item_id:
			directive = candidate
	assert_object(directive).is_not_null()
	var levels: Array[int] = []
	for type: int in directive.hand_types:
		levels.append(loop.state.hand_levels.level_of(type as Pattern.Type))
	var coupons: int = loop.state.coupons
	assert_int(loop.player_envelope_pick(1)).is_equal(RunLoop.Reason.OK)
	for index: int in directive.hand_types.size():
		var type: Pattern.Type = directive.hand_types[index] as Pattern.Type
		assert_int(loop.state.hand_levels.level_of(type)).is_equal(levels[index] + 1)
	assert_int(loop.state.coupons).is_equal(coupons)
	assert_object(loop.open_envelope()).is_null()


## A Directive whose family is all at the top level is never put in an envelope; with
## only one family below it, the envelope shows that one alone.
func test_a_maxed_directive_never_appears() -> void:
	for seed_value: int in 10:
		var loop: RunLoop = _at_the_shops(seed_value)
		for type: int in range(Pattern.Type.TRIO, Pattern.Type.size()):
			while not loop.state.hand_levels.is_max(type as Pattern.Type):
				loop.state.hand_levels.raise(type as Pattern.Type)
		_offer(loop, "directive_envelope")
		assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
		assert_array(_ids(loop.shop.envelopes.items())).is_equal(["0:on_hand_tools:-1:-1"])


func test_keeping_a_campaign_needs_room_and_nothing_is_always_allowed() -> void:
	var loop: RunLoop = _at_the_shops(7)
	_offer(loop, "campaign_envelope")
	loop.state.inventory.consumables.assign(["grain_loan", "appeal"])
	assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
	var items: Array[EnvelopeItem] = loop.shop.envelopes.items()
	var pool: Array[String] = []
	for campaign: CampaignDef in RunPools.STORE_CAMPAIGNS.campaigns:
		pool.append(campaign.id)
	for item: EnvelopeItem in items:
		assert_bool(pool.has(item.item_id)).is_true()
	assert_int(loop.shop.envelopes.check_pick(0)).is_equal(RunShop.Reason.CAMPAIGNS_FULL)
	assert_int(loop.player_envelope_pick(0)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.state.inventory.consumables.size()).is_equal(2)
	loop.state.inventory.consumables.assign(["grain_loan"])
	assert_int(loop.player_envelope_pick(2)).is_equal(RunLoop.Reason.OK)
	assert_array(loop.state.inventory.consumables).is_equal(["grain_loan", items[2].item_id])


func test_supply_cooperative_adds_a_choice_to_every_envelope() -> void:
	for seed_value: int in 4:
		var loop: RunLoop = _at_the_shops(seed_value, ["supply_cooperative"])
		assert_int(loop.player_envelope_buy(0)).is_equal(RunLoop.Reason.OK)
		assert_int(loop.shop.envelopes.items().size()).is_equal(4)
		loop.player_envelope_pick(EnvelopeCounter.NOTHING)
		assert_int(loop.player_market_envelope(0)).is_equal(RunLoop.Reason.OK)
		assert_int(loop.market.envelopes.items().size()).is_equal(4)


## The Parcel holds private Campaigns and marked plot cards, adds Resentment when it is
## bought and none when an item is kept.
func test_the_parcel_mixes_its_contents_and_is_resented_when_bought() -> void:
	var kinds: Dictionary[int, bool] = {}
	var pool: Array[String] = []
	for campaign: CampaignDef in RunPools.MARKET_CAMPAIGNS.campaigns:
		pool.append(campaign.id)
	for seed_value: int in 12:
		var loop: RunLoop = _at_the_shops(seed_value)
		var resentment: int = loop.state.resentment
		var price: int = loop.market.envelopes.price(0)
		assert_int(loop.player_market_envelope(0)).is_equal(RunLoop.Reason.OK)
		assert_dict(loop.record.commands[-1]).is_equal({"type": "market_envelope", "slot": 0})
		assert_int(loop.state.resentment).is_equal(resentment + RESENTMENT.private_purchase)
		assert_int(loop.state.coupons).is_equal(RICH - price)
		for item: EnvelopeItem in loop.market.envelopes.items():
			kinds[item.content] = true
			if item.content == EnvelopeDef.Content.CAMPAIGN:
				assert_bool(pool.has(item.item_id)).is_true()
			else:
				assert_bool(item.is_plot_card()).is_true()
				assert_bool(Ranks.is_valid(item.rank) and item.rank <= Ranks.TWO).is_true()
				assert_bool(item.suit >= 0 and item.suit < Deck.SUITS).is_true()
		var after_buy: int = loop.state.resentment
		assert_int(loop.player_envelope_pick(0)).is_equal(RunLoop.Reason.OK)
		assert_int(loop.state.resentment).is_equal(after_buy)
	assert_int(kinds.size()).is_equal(3)
	assert_bool(kinds.has(EnvelopeDef.Content.DIRECTIVE)).is_false()

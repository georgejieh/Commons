class_name RunShopVisit
extends RefCounted
## A visit to the shops between Sets: the state store and the black market with their
## counters, the plot stall and the deck stall, what each purchase and sale does to the
## run, and reeducation, which is served in a visit's place. The loop opens the visit,
## gates and records every command; each command here returns whether it was done, and
## changes nothing when it was not.

## The state store between Sets. Read it freely; buy and reroll through the loop's commands.
var shop: RunShop
## The black market's counter, open for the same visit as the state store.
var market: RunShop
## The black market's cards for the private plot.
var stall: PlotStall
## The state store's cards for the communal deck (ADR 0042).
var deck_stall: DeckStall

var _state: RunState
var _log: SetLog
var _stack: ModifierStack
var _meters: MeterTable
var _params: RunParams
var _pools: RunPools
var _debuffs: RunDebuffs
var _tutorial: RunTutorial


func _init(
	state: RunState,
	set_log: SetLog,
	stack: ModifierStack,
	meters: MeterTable,
	params: RunParams,
	pools: RunPools,
	debuffs: RunDebuffs,
	tutorial: RunTutorial
) -> void:
	_state = state
	_log = set_log
	_stack = stack
	_meters = meters
	_params = params
	_pools = pools
	_debuffs = debuffs
	_tutorial = tutorial
	shop = RunShop.new(
		state,
		pools.store,
		pools.store_cadres,
		meters.rationing_shop_cut,
		pools.directives,
		pools.store_campaigns,
		pools.reforms,
		params
	)
	var no_directives: Array[DirectiveDef] = []
	var no_reforms: Array[ReformDef] = []
	market = RunShop.new(
		state,
		pools.market,
		pools.market_cadres,
		0,
		no_directives,
		pools.market_campaigns,
		no_reforms,
		params
	)
	stall = PlotStall.new(state, pools.plot_cards, params)
	deck_stall = DeckStall.new(state, pools.deck_cards, params)


## Opens the state store and the black market for a visit, with fresh stock on every
## counter.
func open() -> void:
	shop.short_cut = RunDebuffs.store_cut(_state, RunDefinitions.modifiers, RunLoop.PLAYER)
	shop.open()
	market.open()
	_read_shop_rules()
	stall.open()
	# Last on the shop stream, so Directives, Campaigns and Reforms change none of the
	# stock drawn before them.
	shop.stock_directives()
	shop.campaigns.draw()
	market.campaigns.draw()
	shop.reforms.draw()
	# The envelopes last of all, so they leave every draw before them as it was.
	shop.envelopes.draw()
	market.envelopes.draw()
	# The desks and the deck stall draw on streams of their own, and the arrival has none
	# of them (ADR 0041, ADR 0042).
	shop.desk.open(_tutorial != null)
	market.desk.open(_tutorial != null)
	deck_stall.open(_tutorial != null)


## The counter whose envelope is open now, or null.
func open_envelope() -> EnvelopeCounter:
	for counter: RunShop in [shop, market]:
		if counter.envelopes.is_open():
			return counter.envelopes
	return null


## Serves owed reeducation in place of the shop: the plot is emptied and one held
## Cadre, drawn on the events stream, is exchanged for one the player does not hold.
func reeducate() -> void:
	_state.reeducation_due = false
	_state.inventory.plot.clear()
	var change: PackedStringArray = Reeducation.change_cadre(
		_state.inventory, _pools.exchange(), _state.streams.stream(RandomStreams.EVENTS)
	)
	_state.cadre_memos.keep_only(_state.inventory.cadres)
	_log.add(RunEvent.new(RunEvent.Type.REEDUCATED, RunLoop.PLAYER, 0, 0.0, ">".join(change)))


## Buys the state store's Cadre in slot.
func buy(slot: int) -> bool:
	var bought: ModifierDef = _stocked(shop, slot)
	if shop.buy(slot) != RunShop.Reason.OK:
		return false
	RunCadres.bought(_state, bought, Ranks.INVALID)
	_read_shop_rules()
	return true


## Rerolls the state store's Cadres.
func reroll() -> bool:
	return shop.reroll() == RunShop.Reason.OK


## Issues the state store's Directive in slot.
func directive(slot: int) -> bool:
	return shop.buy_directive(slot) == RunShop.Reason.OK


## Buys the state store's Campaign in slot.
func campaign_buy(slot: int) -> bool:
	return shop.campaigns.buy(slot) == RunShop.Reason.OK


## Enacts the state store's Reform in slot.
func reform(slot: int) -> bool:
	return shop.reforms.buy(slot) == RunShop.Reason.OK


## Buys the state store's envelope in slot, which opens it.
func envelope_buy(slot: int) -> bool:
	return shop.envelopes.buy(slot) == RunShop.Reason.OK


## Buys the black market's Cadre in slot, with the rank it asks for when it asks for one.
func market_buy(slot: int, rank: int) -> bool:
	var bought: ModifierDef = _stocked(market, slot)
	if not RunCadres.rank_fits(bought, rank) or market.buy(slot) != RunShop.Reason.OK:
		return false
	RunCadres.bought(_state, bought, rank)
	_read_shop_rules()
	_market_bought()
	return true


## Rerolls the black market's Cadres.
func market_reroll() -> bool:
	return market.reroll() == RunShop.Reason.OK


## Buys the black market's Campaign in slot.
func market_campaign(slot: int) -> bool:
	return _market_bought_if(market.campaigns.buy(slot) == RunShop.Reason.OK)


## Buys the black market's Parcel in slot, which opens it.
func market_envelope(slot: int) -> bool:
	return _market_bought_if(market.envelopes.buy(slot) == RunShop.Reason.OK)


## Buys the plot stall's card in slot for the private plot.
func plot_card(slot: int) -> bool:
	return _market_bought_if(stall.buy(slot) == PlotStall.Reason.OK)


## Buys one step of a private-plot upgrade.
func upgrade(kind: String) -> bool:
	return _market_bought_if(PlotUpgrades.buy(_state, kind, RunDefaults.PLOT_UPGRADES))


## Sells the held Cadre at index to the state store, or with at_market to the black market.
func sell_cadre(index: int, at_market: bool) -> bool:
	var counter: RunShop = market if at_market else shop
	var held: Array[String] = _state.inventory.cadres
	var cadre_id: String = held[index] if index >= 0 and index < held.size() else ""
	var definition: ModifierDef = RunDefinitions.modifiers.get(cadre_id)
	var paid: int = 0 if definition == null else counter.sale_price(definition.cost)
	if counter.sell(index, definition, _debuffs.confiscated_ids()) != RunShop.Reason.OK:
		return false
	shop.withheld.append(cadre_id)
	market.withheld.append(cadre_id)
	_read_shop_rules()
	_log.add(RunEvent.new(RunEvent.Type.CADRE_SOLD, RunLoop.PLAYER, paid, 0.0, cadre_id))
	return true


## Sells the held Campaign at index to the state store, or with at_market to the black
## market.
func sell_campaign(index: int, at_market: bool) -> bool:
	var counter: CampaignCounter = market.campaigns if at_market else shop.campaigns
	var held: Array[String] = _state.inventory.consumables
	var campaign_id: String = held[index] if index >= 0 and index < held.size() else ""
	var definition: CampaignDef = RunDefinitions.campaigns.get(campaign_id)
	var paid: int = 0 if definition == null else counter.sale_price(definition)
	if counter.sell(index, definition) != RunShop.Reason.OK:
		return false
	shop.campaigns.withheld.append(campaign_id)
	market.campaigns.withheld.append(campaign_id)
	_log.add(RunEvent.new(RunEvent.Type.CAMPAIGN_SOLD, RunLoop.PLAYER, paid, 0.0, campaign_id))
	return true


## Marks the deck card with ID card_id at the state store's desk, or with at_market at the
## black market's.
func mark_card(card_id: int, at_market: bool) -> bool:
	var desk: MarkDesk = (market if at_market else shop).desk
	var paid: int = desk.price()
	if desk.mark(card_id, RunLoop.PLAYER) != MarkDesk.Reason.OK:
		return false
	var value: int = CardInstance.mark_value(desk.offer)
	var text: String = str(card_id)
	_log.add(RunEvent.new(RunEvent.Type.DECK_CARD_MARKED, RunLoop.PLAYER, value, paid, text))
	if at_market:
		_market_bought()
	return true


## Buys the state store's card in slot for the communal deck, in place of the deck card
## in out.
func deck_card(slot: int, out: int) -> bool:
	return deck_stall.buy(slot, out) == RunShop.Reason.OK


## What the held Cadres change about this visit's counters, read as it opens and again
## after a Cadre is bought, so one bought now works at once (Back Door, ADR 0032).
func _read_shop_rules() -> void:
	var rules: ShopContext = RunCadres.shop_rules(_state, RunDefinitions.modifiers, RunLoop.PLAYER)
	market.free_rerolls = rules.free_market_rerolls


## The Cadre on a counter's slot, or null for an empty or sold one.
func _stocked(counter: RunShop, slot: int) -> ModifierDef:
	var stock: Array[String] = counter.stock()
	if slot < 0 or slot >= stock.size() or stock[slot] == RunShop.SOLD:
		return null
	return RunDefinitions.modifiers[stock[slot]]


## A black-market purchase that was made is resented; done says whether it was.
func _market_bought_if(done: bool) -> bool:
	if done:
		_market_bought()
	return done


## Every black-market purchase is resented, and counted when it comes in a famine.
## In the arrival someone sees it, too, and Denunciation rises by its own row (ADR 0026).
func _market_bought() -> void:
	Resentment.add(
		_state,
		RunDefaults.RESENTMENT.private_purchase,
		Resentment.PRIVATE_PURCHASE,
		RunDefaults.RESENTMENT,
		_log.events()
	)
	CorruptionEvents.note_purchase(_state, _meters.famine)
	if _tutorial != null:
		RunMeters.apply_amount(
			_state,
			RunTutorial.DENUNCIATION_ROW,
			_tutorial.denunciation(),
			_meters,
			_stack,
			_params,
			RunLoop.PLAYER,
			_log.events()
		)

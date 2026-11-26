class_name RunStoreView
extends RefCounted
## The shops this visit, for a screen to read: each counter's shelf and desk, the
## stock, and the communal deck the state store exchanges cards in (ADR 0042).
## RunController builds it over each run it attaches, as controller.store.

var _loop: RunLoop


func _init(loop: RunLoop) -> void:
	_loop = loop


## The state store's counter, or the black market's, for a screen to read.
func desk(market: bool) -> ShopDesk:
	if market:
		var upgrades: PlotUpgradeParams = RunDefaults.PLOT_UPGRADES
		var at_market: ShopDesk = ShopDesk.new(
			_loop.visit.market, _loop.state, upgrades, _loop.visit.stall
		)
		at_market.bound = _loop.debuffs.confiscated_ids()
		return at_market
	var at_store: ShopDesk = ShopDesk.new(_loop.visit.shop, _loop.state)
	at_store.bound = _loop.debuffs.confiscated_ids()
	return at_store


## The store's stock per slot, an empty ID for a sold slot.
func store_stock() -> Array[String]:
	return _loop.visit.shop.stock()


## True when the state store's Cadre in slot can be bought now.
func can_buy(slot: int) -> bool:
	return _loop.visit.shop.check_buy(slot) == RunShop.Reason.OK


## Cadres Short Supply keeps off the state store's counter this visit.
func short_supply() -> int:
	return _loop.visit.shop.short_cut


## The Campaigns on the state store's counter, or the black market's.
func campaign_shelf(market: bool) -> CampaignShelf:
	return CampaignShelf.new(_loop.visit.market.campaigns if market else _loop.visit.shop.campaigns)


## The Reform on the state store's counter, for a screen to read.
func reform_shelf() -> ReformShelf:
	return ReformShelf.new(_loop.visit.shop.reforms)


## The envelope on the state store's counter, or the black market's, for a screen to read.
func envelope_shelf(market: bool) -> EnvelopeShelf:
	var counter: RunShop = _loop.visit.market if market else _loop.visit.shop
	return EnvelopeShelf.new(counter.envelopes, RunLoop.PLAYER, market)


## The shelf whose envelope is open now, or null when none is.
func opened_envelope() -> EnvelopeShelf:
	for market: bool in [false, true]:
		var shelf: EnvelopeShelf = envelope_shelf(market)
		if shelf.is_open():
			return shelf
	return null


## The state store's desk this visit, or with market the black market's, as a screen
## reads it (ADR 0041).
func mark_desk(market: bool) -> DeskView:
	return DeskView.new((_loop.visit.market if market else _loop.visit.shop).desk, _loop.state)


## The state store's stall of cards for the deck this visit, for a screen to read.
func deck_stall() -> DeckStallView:
	return DeckStallView.new(_loop.visit.deck_stall)


## The 54 deck cards as the next deal will find them, in slot order, each a copy with
## the marks the run has saved on it (ADR 0041), the state store's exchanges in place
## (ADR 0042).
func deck_cards() -> Array[CardInstance]:
	var cards: Array[CardInstance] = _loop.state.deck.cards()
	_loop.state.card_marks.apply(cards)
	return cards


## The plain deck's card the state store replaced in slot (ADR 0042), or null when the
## slot holds its plain card.
func replaced(slot: int) -> CardInstance:
	if not _loop.state.deck.changed_slots().has(slot):
		return null
	return Deck.new().card(slot)


## How many slots of the deck hold a card the state store put there.
func exchanged_count() -> int:
	return _loop.state.deck.changed_slots().size()

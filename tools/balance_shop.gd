class_name BalanceShop
extends RefCounted
## Reads both counters into a BalanceVisit through the controller's shelves, and buys an
## offer through its commands. Only what can be bought now is offered, so every purchase
## the harness sends is one the run accepts.


## What both shops offer the player now, with the coupons to spend on it.
static func visit(controller: RunController, state: RunState) -> BalanceVisit:
	var seen: BalanceVisit = BalanceVisit.new()
	seen.coupons = state.coupons
	seen.resentment = state.resentment
	var deck: Array[CardInstance] = controller.store.deck_cards()
	_store(controller, deck, seen.store)
	_market(controller, deck, seen.market)
	seen.can_reroll = controller.store.desk(true).can_reroll()
	return seen


static func _store(
	controller: RunController, deck: Array[CardInstance], offers: Array[BalanceOffer]
) -> void:
	var desk: ShopDesk = controller.store.desk(false)
	var directives: Array[String] = desk.directive_stock()
	for slot: int in directives.size():
		if desk.can_buy_directive(slot):
			var cost: int = desk.directive_price(slot)
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.DIRECTIVE, slot, cost, false, directives[slot])
			)
	var stock: Array[String] = desk.stock()
	for slot: int in stock.size():
		if desk.can_buy(slot):
			offers.append(
				BalanceOffer.new(
					BalanceOffer.Kind.CADRE, slot, desk.price(slot), false, stock[slot]
				)
			)
	var reforms: ReformShelf = controller.store.reform_shelf()
	for slot: int in reforms.stock().size():
		if reforms.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.REFORM, slot, reforms.price(slot), false)
			)
	var envelopes: EnvelopeShelf = controller.store.envelope_shelf(false)
	for slot: int in envelopes.stock().size():
		if envelopes.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.ENVELOPE, slot, envelopes.price(slot), false)
			)
	var campaigns: CampaignShelf = controller.store.campaign_shelf(false)
	for slot: int in campaigns.stock().size():
		if campaigns.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.CAMPAIGN, slot, campaigns.price(slot), false)
			)
	_deck_stall(controller, deck, offers)
	_desk(controller, deck, false, offers)


## The deck stall's cards that rank above the deck's weakest card in the plain order, each
## to go in that card's place (ADR 0027): a card no better than the one it replaces would
## only spend coupons.
static func _deck_stall(
	controller: RunController, deck: Array[CardInstance], offers: Array[BalanceOffer]
) -> void:
	var stall: DeckStallView = controller.store.deck_stall()
	var out: int = weakest_slot(deck)
	var weakest: int = deck[out].base_rank()
	for slot: int in stall.count():
		var card: CardInstance = stall.card(slot)
		if card == null or card.base_rank() <= weakest or not stall.refusal(slot, out).is_empty():
			continue
		var offer: BalanceOffer = BalanceOffer.new(
			BalanceOffer.Kind.DECK_CARD, slot, stall.price(slot), false
		)
		offer.card = out
		offers.append(offer)


## The desk's one use this visit, on the card mark_target names, when the desk takes it.
static func _desk(
	controller: RunController, deck: Array[CardInstance], market: bool, offers: Array[BalanceOffer]
) -> void:
	var desk: DeskView = controller.store.mark_desk(market)
	if not desk.affordable():
		return
	var target: int = mark_target(deck, desk.stamps())
	if target == RunController.NO_CARD or not desk.refusal(target).is_empty():
		return
	var offer: BalanceOffer = BalanceOffer.new(
		BalanceOffer.Kind.MARK, 0, desk.price(), market, desk.offer()
	)
	offer.card = target
	offers.append(offer)


static func _market(
	controller: RunController, deck: Array[CardInstance], offers: Array[BalanceOffer]
) -> void:
	var desk: ShopDesk = controller.store.desk(true)
	var stock: Array[String] = desk.stock()
	for slot: int in stock.size():
		if desk.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.CADRE, slot, desk.price(slot), true, stock[slot])
			)
	var parcels: EnvelopeShelf = controller.store.envelope_shelf(true)
	for slot: int in parcels.stock().size():
		if parcels.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.PARCEL, slot, parcels.price(slot), true)
			)
	for slot: int in desk.plot_card_count():
		if desk.can_buy_plot_card(slot):
			var price: int = desk.plot_card_price(slot)
			offers.append(BalanceOffer.new(BalanceOffer.Kind.PLOT_CARD, slot, price, true))
	for kind: String in desk.upgrade_kinds():
		if desk.can_upgrade(kind):
			var cost: int = desk.upgrade_price(kind)
			offers.append(BalanceOffer.new(BalanceOffer.Kind.UPGRADE, 0, cost, true, kind))
	_desk(controller, deck, true, offers)


## Sends the command that buys offer; rank is the pick for a Cadre that needs one.
## Returns the controller's reason.
static func buy(controller: RunController, offer: BalanceOffer, rank: int) -> int:
	match offer.kind:
		BalanceOffer.Kind.CADRE:
			if offer.market:
				return controller.market_buy(offer.slot, rank)
			return controller.buy(offer.slot)
		BalanceOffer.Kind.DIRECTIVE:
			return controller.directive(offer.slot)
		BalanceOffer.Kind.REFORM:
			return controller.reform(offer.slot)
		BalanceOffer.Kind.ENVELOPE:
			return controller.envelope_buy(offer.slot, false)
		BalanceOffer.Kind.CAMPAIGN:
			return controller.campaign_buy(offer.slot, false)
		BalanceOffer.Kind.PARCEL:
			return controller.envelope_buy(offer.slot, true)
		BalanceOffer.Kind.PLOT_CARD:
			return controller.plot_card(offer.slot)
		BalanceOffer.Kind.DECK_CARD:
			return controller.exchange_card(offer.slot, offer.card)
		BalanceOffer.Kind.MARK:
			return controller.mark_card(offer.card, offer.market)
	return controller.upgrade(offer.item_id)


## Keeps the open envelope's first item the player can keep, or nothing, and returns the
## controller's answer. A card for the communal deck goes in place of the deck's weakest
## card (ADR 0042).
static func keep_from(controller: RunController, shelf: EnvelopeShelf) -> int:
	var pick: int = RunController.TAKE_NOTHING
	for index: int in shelf.count():
		if shelf.can_take(index):
			pick = index
			break
	var out: int = RunController.NO_CARD
	if pick != RunController.TAKE_NOTHING and shelf.is_deck_card(pick):
		out = weakest_slot(controller.store.deck_cards())
	return controller.envelope_pick(pick, out)


## The deck card a desk marks (ADR 0027): the highest in the plain order that carries no
## mark of the desk's kind, an enhancement or with stamps the player's stamp, so a use
## never replaces an enhancement; the lowest slot on a tie. NO_CARD when every card
## carries one. deck is in slot order, as RunStoreView.deck_cards() gives it.
static func mark_target(deck: Array[CardInstance], stamps: bool) -> int:
	var best: CardInstance = null
	for card: CardInstance in deck:
		var marked: bool = (
			card.owner_stamp() != CardInstance.NO_OWNER
			if stamps
			else card.enhancement_id() != CardInstance.NO_ID
		)
		if not marked and (best == null or card.base_rank() > best.base_rank()):
			best = card
	return RunController.NO_CARD if best == null else best.id()


## The first slot of the lowest rank the deck holds, which every strategy trades away for
## a card from an envelope or the deck stall. Never a joker's, which may not leave: the
## jokers rank above every other card. deck is in slot order.
static func weakest_slot(deck: Array[CardInstance]) -> int:
	var weakest: CardInstance = deck[0]
	for card: CardInstance in deck:
		if card.base_rank() < weakest.base_rank():
			weakest = card
	return weakest.id()

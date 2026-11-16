class_name BalanceShop
extends RefCounted
## Reads both counters into a BalanceVisit through the controller's shelves, and buys an
## offer through its commands. Only what can be bought now is offered, so every purchase
## the harness sends is one the run accepts.


static func visit(controller: RunController, state: RunState) -> BalanceVisit:
	var seen: BalanceVisit = BalanceVisit.new()
	seen.coupons = state.coupons
	seen.resentment = state.resentment
	_store(controller, seen.store)
	_market(controller, seen.market)
	seen.can_reroll = controller.desk(true).can_reroll()
	return seen


static func _store(controller: RunController, offers: Array[BalanceOffer]) -> void:
	var desk: ShopDesk = controller.desk(false)
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
	var reforms: ReformShelf = controller.reform_shelf()
	for slot: int in reforms.stock().size():
		if reforms.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.REFORM, slot, reforms.price(slot), false)
			)
	var envelopes: EnvelopeShelf = controller.envelope_shelf(false)
	for slot: int in envelopes.stock().size():
		if envelopes.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.ENVELOPE, slot, envelopes.price(slot), false)
			)
	var campaigns: CampaignShelf = controller.campaign_shelf(false)
	for slot: int in campaigns.stock().size():
		if campaigns.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.CAMPAIGN, slot, campaigns.price(slot), false)
			)


static func _market(controller: RunController, offers: Array[BalanceOffer]) -> void:
	var desk: ShopDesk = controller.desk(true)
	var stock: Array[String] = desk.stock()
	for slot: int in stock.size():
		if desk.can_buy(slot):
			offers.append(
				BalanceOffer.new(BalanceOffer.Kind.CADRE, slot, desk.price(slot), true, stock[slot])
			)
	var parcels: EnvelopeShelf = controller.envelope_shelf(true)
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
	return controller.upgrade(offer.item_id)


## The open envelope's first item the player can keep, or the pick that keeps nothing.
static func envelope_pick(shelf: EnvelopeShelf) -> int:
	for index: int in shelf.count():
		if shelf.can_take(index):
			return index
	return RunController.TAKE_NOTHING

class_name BalanceOffer
extends RefCounted
## One thing a counter offers that the player can buy now, and its price.

enum Kind { CADRE, REFORM, ENVELOPE, CAMPAIGN, PARCEL, PLOT_CARD, UPGRADE, DIRECTIVE }

var kind: Kind
## The slot on its shelf; for an upgrade, unused.
var slot: int
var price: int
## True at the black market.
var market: bool
## The Cadre's or Directive's ID, or the upgrade's kind; empty otherwise.
var item_id: String


func _init(
	offer_kind: Kind, offer_slot: int, offer_price: int, at_market: bool, id: String = ""
) -> void:
	kind = offer_kind
	slot = offer_slot
	price = offer_price
	market = at_market
	item_id = id


## The dearest offer of a kind at or under budget, the first on the shelf on a tie, or
## null. A negative kind matches every kind.
static func dearest(offers: Array[BalanceOffer], wanted: int, budget: int) -> BalanceOffer:
	var best: BalanceOffer = null
	for offer: BalanceOffer in offers:
		if wanted >= 0 and offer.kind != wanted:
			continue
		if offer.price > budget:
			continue
		if best == null or offer.price > best.price:
			best = offer
	return best


## The cheapest offer of a kind at or under budget, the first on the shelf on a tie, or
## null.
static func cheapest(offers: Array[BalanceOffer], wanted: int, budget: int) -> BalanceOffer:
	var best: BalanceOffer = null
	for offer: BalanceOffer in offers:
		if offer.kind != wanted or offer.price > budget:
			continue
		if best == null or offer.price < best.price:
			best = offer
	return best

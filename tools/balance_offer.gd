class_name BalanceOffer
extends RefCounted
## One thing a counter offers that the player can buy now, and its price.

enum Kind {
	CADRE,
	REFORM,
	ENVELOPE,
	CAMPAIGN,
	PARCEL,
	PLOT_CARD,
	UPGRADE,
	DIRECTIVE,
	DECK_CARD,
	MARK,
}

var kind: Kind
## The slot on its shelf; for an upgrade, unused.
var slot: int
var price: int
## True at the black market.
var market: bool
## The Cadre's or Directive's ID, the upgrade's kind or the enhancement a desk gives;
## empty otherwise, and at the desk that stamps.
var item_id: String
## The deck card a card for the deck takes the place of, or the one a desk marks;
## RunController.NO_CARD for every other kind.
var card: int = RunController.NO_CARD


func _init(
	offer_kind: Kind, offer_slot: int, offer_price: int, at_market: bool, id: String = ""
) -> void:
	kind = offer_kind
	slot = offer_slot
	price = offer_price
	market = at_market
	item_id = id


## The dearest offer of kind wanted at or under budget, the first on the shelf on a tie,
## or null.
static func dearest(offers: Array[BalanceOffer], wanted: Kind, budget: int) -> BalanceOffer:
	return _best(
		offers.filter(func(offer: BalanceOffer) -> bool: return offer.kind == wanted), budget, true
	)


## The dearest offer of any kind at or under budget, the first on the shelf on a tie, or
## null.
static func dearest_of_any(offers: Array[BalanceOffer], budget: int) -> BalanceOffer:
	return _best(offers, budget, true)


## The cheapest offer of kind wanted at or under budget, the first on the shelf on a tie,
## or null.
static func cheapest(offers: Array[BalanceOffer], wanted: Kind, budget: int) -> BalanceOffer:
	return _best(
		offers.filter(func(offer: BalanceOffer) -> bool: return offer.kind == wanted), budget, false
	)


## The dearest offer, or the cheapest, at or under budget; the first on a tie.
static func _best(offers: Array, budget: int, dearer: bool) -> BalanceOffer:
	var best: BalanceOffer = null
	for offer: BalanceOffer in offers:
		if offer.price > budget:
			continue
		if best == null or (offer.price > best.price if dearer else offer.price < best.price):
			best = offer
	return best

class_name DeckStallView
extends RefCounted
## The state store's stall of cards for the communal deck as a screen reads it (ADR
## 0042): whether it sells this visit, each offer as the card it would put in the deck,
## its price, and why it could not be bought now or could not replace a given deck card.
## It only reads; a purchase goes through RunController.exchange_card.

## Why an offer cannot be bought now, before any deck card is named.
enum Why { NONE, SOLD, POOR, AT_MOST }

var _stall: DeckStall


func _init(stall: DeckStall) -> void:
	_stall = stall


## True when the stall sells this visit.
func is_open() -> bool:
	return _stall.is_open


## How many offers the stall has, sold ones included.
func count() -> int:
	return _stall.offers.count()


## The most cards of one rank the deck may hold.
func most() -> int:
	return _stall.most()


## The offer as it would come into the deck, its enhancement on it, or null once sold.
## A stand-in to show: it takes the slot of the deck card it replaces.
func card(slot: int) -> CardInstance:
	if _stall.offers.rank(slot) == CardOffers.SOLD:
		return null
	var shown: CardInstance = CardInstance.new(
		-1 - slot, _stall.offers.rank(slot), _stall.offers.suit(slot), CardInstance.Origin.DECK
	)
	if _stall.offers.enhancement(slot) != CardInstance.NO_ID:
		CardModifiers.enhance(shown, _stall.offers.enhancement(slot))
	return shown


## The price in coupons of the offer in slot.
func price(slot: int) -> int:
	return _stall.offers.price(slot)


## Why the offer in slot cannot be bought now, or NONE when it can.
func why(slot: int) -> Why:
	match _stall.check(slot):
		RunShop.Reason.OK:
			return Why.NONE
		RunShop.Reason.TOO_POOR:
			return Why.POOR
		RunShop.Reason.AT_MOST:
			return Why.AT_MOST
	return Why.SOLD


## Why the offer could not replace the deck card in out, as the key of the words that say
## so, or "" when it could.
func refusal(slot: int, out: int) -> String:
	match _stall.check_exchange(slot, out):
		RunShop.Reason.OK:
			return ""
		RunShop.Reason.JOKER:
			return "exchange.refused.joker"
		RunShop.Reason.TOO_POOR:
			return "deck.refused.poor"
		RunShop.Reason.AT_MOST:
			return "exchange.refused.at_most"
	return "exchange.refused.other"

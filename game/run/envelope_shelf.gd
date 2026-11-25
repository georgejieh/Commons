class_name EnvelopeShelf
extends RefCounted
## A shop's envelope for a screen to read (ADR 0021): what is offered, at what price and
## whether it can be bought now, then, once it is open, what it shows and whether each
## item can be kept. Buying and keeping go through the run controller.

const KIND_DIRECTIVE: int = EnvelopeDef.Content.DIRECTIVE
const KIND_CAMPAIGN: int = EnvelopeDef.Content.CAMPAIGN
const KIND_STAMPED: int = EnvelopeDef.Content.STAMPED_CARD
const KIND_MODEL: int = EnvelopeDef.Content.MODEL_CARD
const KIND_DECK: int = EnvelopeDef.Content.DECK_CARD
const KIND_MARKED_DECK: int = EnvelopeDef.Content.MARKED_DECK_CARD
## The wrappings, for the screen's drawings.
const STRING_TIE: int = EnvelopeDef.Wrapping.STRING_TIE
const WAX_SEAL: int = EnvelopeDef.Wrapping.WAX_SEAL
const PARCEL: int = EnvelopeDef.Wrapping.PARCEL

## True for the black market's counter.
var market: bool = false

var _counter: EnvelopeCounter
var _seat: int


func _init(counter: EnvelopeCounter, seat: int, from_market: bool) -> void:
	_counter = counter
	_seat = seat
	market = from_market


## Envelope IDs per slot, an empty ID for one already bought.
func stock() -> Array[String]:
	return _counter.stock()


func price(slot: int) -> int:
	return _counter.price(slot)


func can_buy(slot: int) -> bool:
	return _counter.check(slot) == RunShop.Reason.OK


## An envelope's name, rules and wrapping, with how many items it shows filled in.
func envelope_name(envelope_id: String) -> String:
	return tr(_counter.definition(envelope_id).name_key)


func envelope_text(envelope_id: String) -> String:
	var text: String = tr(_counter.definition(envelope_id).text_key)
	return text.format({"choices": _counter.choices(envelope_id)})


func wrapping(envelope_id: String) -> int:
	return _counter.definition(envelope_id).wrapping


## The envelope bought this visit, or empty: its place on the counter shows it opened.
func bought_id() -> String:
	return _counter.bought_id()


func is_open() -> bool:
	return _counter.is_open()


## The open envelope's ID, or empty.
func opened_id() -> String:
	return _counter.opened_id()


## What the open envelope shows: how many items, and each one's kind and ID.
func count() -> int:
	return _counter.items().size()


func kind(index: int) -> int:
	return _counter.items()[index].content


func item_id(index: int) -> String:
	return _counter.items()[index].item_id


## A card in the envelope as it would enter the plot or the deck, its mark on it. A
## stand-in to show: a plot card gets its real plot ID when it is kept, and a deck card
## the slot of the card it replaces.
func card(index: int) -> CardInstance:
	var item: EnvelopeItem = _counter.items()[index]
	if item.is_deck_card():
		var dealt: CardInstance = CardInstance.new(
			-1 - index, item.rank, item.suit, CardInstance.Origin.DECK
		)
		if item.enhancement != CardInstance.NO_ID:
			CardModifiers.enhance(dealt, item.enhancement)
		return dealt
	if not item.is_plot_card():
		return null
	var shown: CardInstance = CardInstance.new(
		-1 - index, item.rank, item.suit, CardInstance.Origin.PLOT
	)
	if item.content == EnvelopeDef.Content.STAMPED_CARD:
		CardModifiers.stamp(shown, _seat)
	else:
		CardModifiers.enhance(shown, CardInstance.MODEL)
	return shown


## True for a card for the communal deck, which is kept by naming the deck card it
## replaces (ADR 0042).
func is_deck_card(index: int) -> bool:
	return _counter.items()[index].is_deck_card()


## Why the deck card at index could not replace the deck card in out, as the key of the
## words that say so, or "" when it could.
func exchange_refusal(index: int, out: int) -> String:
	match _counter.check_pick(index, out):
		RunShop.Reason.OK:
			return ""
		RunShop.Reason.JOKER:
			return "exchange.refused.joker"
		RunShop.Reason.AT_MOST:
			return "exchange.refused.at_most"
	return "exchange.refused.other"


func can_take(index: int) -> bool:
	return _counter.check_pick(index) == RunShop.Reason.OK


## The string key saying why the item cannot be kept now, or empty when it can.
func refusal_key(index: int) -> String:
	match _counter.check_pick(index):
		RunShop.Reason.OK:
			return ""
		RunShop.Reason.CAMPAIGNS_FULL:
			return "envelope.refused.campaigns_full"
		RunShop.Reason.PLOT_FULL:
			return "envelope.refused.plot_full"
		RunShop.Reason.SOLD_BACK:
			return "envelope.refused.sold_back"
		RunShop.Reason.AT_MOST:
			return "exchange.refused.at_most"
	return "envelope.refused.other"

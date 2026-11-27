class_name EnvelopeShelf
extends RefCounted
## A shop's envelope for a screen to read (ADR 0021): what is offered, at what price and
## whether it can be bought now, then, once it is open, what it shows and whether each
## item can be kept. Buying and keeping go through the run controller.

## The kind of an item that is a Directive.
const KIND_DIRECTIVE: int = EnvelopeDef.Content.DIRECTIVE
## The kind of an item that is a Campaign.
const KIND_CAMPAIGN: int = EnvelopeDef.Content.CAMPAIGN
## The kind of an item that is a stamped card for the plot.
const KIND_STAMPED: int = EnvelopeDef.Content.STAMPED_CARD
## The kind of an item that is a model card for the plot.
const KIND_MODEL: int = EnvelopeDef.Content.MODEL_CARD
## The kind of an item that is a card for the communal deck.
const KIND_DECK: int = EnvelopeDef.Content.DECK_CARD
## The kind of an item that is a card for the communal deck, marked.
const KIND_MARKED_DECK: int = EnvelopeDef.Content.MARKED_DECK_CARD

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


## The price in coupons of the envelope in slot.
func price(slot: int) -> int:
	return _counter.price(slot)


## True when the envelope in slot can be bought now.
func can_buy(slot: int) -> bool:
	return _counter.check(slot) == RunShop.Reason.OK


## The envelope's name, as the string table gives it.
func envelope_name(envelope_id: String) -> String:
	return tr(_counter.definition(envelope_id).name_key)


## The envelope's rules, with how many items it shows filled in.
func envelope_text(envelope_id: String) -> String:
	var text: String = tr(_counter.definition(envelope_id).text_key)
	return text.format({"choices": _counter.choices(envelope_id)})


## How the envelope is wrapped, for the screen to draw.
func wrapping(envelope_id: String) -> EnvelopeDef.Wrapping:
	return _counter.definition(envelope_id).wrapping


## The envelope bought this visit, or empty: its place on the counter shows it opened.
func bought_id() -> String:
	return _counter.bought_id()


## True once the bought envelope has been opened.
func is_open() -> bool:
	return _counter.is_open()


## The open envelope's ID, or empty.
func opened_id() -> String:
	return _counter.opened_id()


## How many items the open envelope shows.
func count() -> int:
	return _counter.items().size()


## The kind of item index in the open envelope, one of the KIND_ constants.
func kind(index: int) -> int:
	return _counter.items()[index].content


## The ID of item index in the open envelope; a card has none.
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


## True when item index can be kept now.
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

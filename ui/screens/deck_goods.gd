class_name DeckGoods
extends RefCounted
## The state store's stall of cards for the communal deck (ADR 0042), the counterpart of
## the black market's plot stall (MarketGoods): a few cards at the end of the row of
## buttons, each its real face, at a card's proportions and the row's height, beside its
## Buy ticket, whose slip names the card and the rule. The page has no room for another
## paper at the largest text with the most a run holds, so the stall takes the row's
## spare width. A ticket that cannot be pressed says why, the rank at its most among the
## reasons. Pressing one opens the deck sheet on an ExchangeChoice, where the card coming
## in stands full size beside the heading, the player picks the card that leaves, sees
## both named and confirms or backs out; the exchange goes through the run controller.

## The cards' scale: no taller than the row's tickets at the largest text, and the rank
## printed at 16 px, past the least type the page may use.
const CARD_SCALE: float = 0.4
const GAP: int = 6

## The offers, for the row of buttons.
var strip: HBoxContainer = HBoxContainer.new()

var _shop: StallContext
var _items: Array[BuyItem] = []


func setup(shop: StallContext) -> void:
	_shop = shop
	strip.add_theme_constant_override("separation", ScreenKit.STYLE.gap)


## The Buy ticket under an offer, or null, for tests and the playtest.
func card_button(slot: int) -> Button:
	return _items[slot].buy if slot < _items.size() else null


## The card shown in an offer's place, for tests.
func card_view(slot: int) -> CardView:
	return _items[slot].view if slot < _items.size() else null


## Shows the offers as the stall stands; through the arrival there is no stall.
func refresh() -> void:
	ScreenKit.clear(strip)
	_items.clear()
	var stall: DeckStallView = _shop.controller.store.deck_stall()
	strip.visible = stall.is_open()
	if not stall.is_open():
		return
	var coupons: int = _shop.controller.run.coupons()
	for slot: int in stall.count():
		_offer(stall, slot, coupons)


func _offer(stall: DeckStallView, slot: int, coupons: int) -> void:
	var card: CardInstance = stall.card(slot)
	var item: BuyItem = BuyItem.new(strip, card, CARD_SCALE, GAP)
	if card != null:
		var why: DeckStallView.Why = stall.why(slot)
		var otherwise: BuyTicket.Why = BuyTicket.Why.FULL
		if why == DeckStallView.Why.AT_MOST:
			otherwise = BuyTicket.Why.AT_MOST
		BuyTicket.dress(
			item.buy, why == DeckStallView.Why.NONE, stall.price(slot), coupons, otherwise
		)
	item.buy.pressed.connect(_choose.bind(slot))
	var rule: String = tr("store.deck.tip").format({"most": stall.most()})
	var title: String = "" if card == null else ExchangeChoice.card_text(card)
	_shop.slip.follow(item.buy, title, rule)
	_items.append(item)


## Opens the deck sheet to pick the card the offer replaces.
func _choose(slot: int) -> void:
	if _shop.busy.call():
		return
	var stall: DeckStallView = _shop.controller.store.deck_stall()
	var card: CardInstance = stall.card(slot)
	if card == null:
		return
	_shop.slip.hide_slip()
	var confirm: String = tr("exchange.confirm").format({"price": stall.price(slot)})
	var refuse: Callable = func(out: int) -> String: return stall.refusal(slot, out)
	var act: Callable = func(out: int) -> int: return _shop.controller.exchange_card(slot, out)
	_shop.deck.open_choice(ExchangeChoice.new(card, confirm, refuse, act))

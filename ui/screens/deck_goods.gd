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

const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")
## The cards' scale: no taller than the row's tickets at the largest text, and the rank
## printed at 16 px, past the least type the page may use.
const CARD_SCALE: float = 0.4
const GAP: int = 6

## The offers, for the row of buttons.
var strip: HBoxContainer = HBoxContainer.new()

var _controller: RunController
var _deck: DeckSheet
var _slip: DetailSlip
var _screen_busy: Callable
var _buttons: Array[Button] = []


func setup(controller: RunController, deck: DeckSheet, slip: DetailSlip, busy: Callable) -> void:
	_controller = controller
	_deck = deck
	_slip = slip
	_screen_busy = busy
	strip.add_theme_constant_override("separation", ScreenKit.STYLE.gap)


## The Buy ticket under an offer, or null, for tests and the playtest.
func card_button(slot: int) -> Button:
	return _buttons[slot] if slot < _buttons.size() else null


## The card shown in an offer's place, for tests.
func card_view(slot: int) -> CardView:
	if slot >= _buttons.size():
		return null
	return _buttons[slot].get_parent().get_child(0).get_child(0) as CardView


## Shows the offers as the stall stands; through the arrival there is no stall.
func refresh() -> void:
	for child: Node in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var stall: DeckStallView = _controller.store.deck_stall()
	strip.visible = stall.is_open()
	if not stall.is_open():
		return
	var coupons: int = _controller.state_copy().coupons
	for slot: int in stall.count():
		_offer(stall, slot, coupons)


func _offer(stall: DeckStallView, slot: int, coupons: int) -> void:
	var item: HBoxContainer = HBoxContainer.new()
	item.add_theme_constant_override("separation", GAP)
	# In the tree first: a card view is only ready to show a card once it is in it.
	strip.add_child(item)
	var card: CardInstance = stall.card(slot)
	var view: CardView = CARD_SCENE.instantiate()
	var holder: Control = Control.new()
	holder.custom_minimum_size = (view.custom_minimum_size * CARD_SCALE).floor()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(holder)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(view)
	view.bind(card)
	view.visible = true
	# Scaled from its corner, so it fills its holder at a card's proportions.
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2.ONE * CARD_SCALE
	view.modulate.a = 1.0 if card != null else 0.0
	var buy: Button = ScreenKit.button(_tr("store.sold"), CommonsTheme.COUPON)
	buy.custom_minimum_size = Vector2.ZERO
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", TextSize.px(CounterPanel.BUY_SIZE))
	buy.disabled = true
	BuyTicket.readable(buy)
	if card != null:
		var why: DeckStallView.Why = stall.why(slot)
		var otherwise: BuyTicket.Why = BuyTicket.Why.FULL
		if why == DeckStallView.Why.AT_MOST:
			otherwise = BuyTicket.Why.AT_MOST
		BuyTicket.dress(buy, why == DeckStallView.Why.NONE, stall.price(slot), coupons, otherwise)
	buy.pressed.connect(_choose.bind(slot))
	var rule: String = _tr("store.deck.tip").format({"most": stall.most()})
	var title: String = "" if card == null else ExchangeChoice.card_text(card)
	buy.mouse_entered.connect(_slip.show_for.bind(buy, title, rule))
	buy.focus_entered.connect(_slip.show_for.bind(buy, title, rule))
	buy.mouse_exited.connect(_slip.hide_for.bind(buy))
	buy.focus_exited.connect(_slip.hide_for.bind(buy))
	item.add_child(buy)
	_buttons.append(buy)


## Opens the deck sheet to pick the card the offer replaces.
func _choose(slot: int) -> void:
	if _screen_busy.call():
		return
	var stall: DeckStallView = _controller.store.deck_stall()
	var card: CardInstance = stall.card(slot)
	if card == null:
		return
	_slip.hide_slip()
	var confirm: String = _tr("exchange.confirm").format({"price": stall.price(slot)})
	var refuse: Callable = func(out: int) -> String: return stall.refusal(slot, out)
	var act: Callable = func(out: int) -> int: return _controller.exchange_card(slot, out)
	_deck.open_choice(ExchangeChoice.new(card, confirm, refuse, act))


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)

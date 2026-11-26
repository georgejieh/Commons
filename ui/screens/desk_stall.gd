class_name DeskStall
extends RefCounted
## A shop's desk (ADR 0041): a ticket on the counter that names the mark
## the desk gives this visit, the state store's enhancement or the black market's stamp,
## and its price, with the desk's rule in the shared slip beside it. Pressed, it opens the
## deck sheet to choose the card; once a card is marked it says so until the next visit,
## and while the coupons are short it is off. Through the arrival there is none.

var ticket: Button = ScreenKit.button("", CommonsTheme.COUPON)

var _desk: DeskView
var _market: bool = false
var _sheet: DeckSheet
var _slip: DetailSlip
var _screen_busy: Callable


func setup(shop: StallContext) -> void:
	_desk = shop.controller.store.mark_desk(shop.market)
	_market = shop.market
	_sheet = shop.deck
	_slip = shop.slip
	_screen_busy = shop.busy
	BuyTicket.readable(ticket)
	ticket.custom_minimum_size = Vector2.ZERO
	ticket.pressed.connect(_choose)
	var stamps: bool = _desk.stamps()
	var title: String = tr("desk.stamp") if stamps else _mark()
	var rule: String = tr("desk.rule.stamp" if stamps else "desk.rule.mark")
	_slip.follow(ticket, title, rule.format({"mark": _mark()}))


## Shows the ticket as the desk stands: offered, done this visit, or gone.
func show_offer() -> void:
	ticket.visible = _desk.is_open()
	if not ticket.visible:
		return
	var values: Dictionary[String, Variant] = {"mark": _mark(), "price": _desk.price()}
	var key: String = "desk.ticket.stamp" if _desk.stamps() else "desk.ticket"
	if _desk.used():
		key = "desk.used.stamp" if _desk.stamps() else "desk.used"
	ticket.text = tr(key).format(values)
	ticket.disabled = not _desk.affordable()


func _mark() -> String:
	return DeckSheet.mark_name(_desk.offer())


func _choose() -> void:
	if _screen_busy.call():
		return
	_slip.hide_slip()
	_sheet.open_choice(DeskChoice.new(_desk, _market))

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
var _screen_busy: Callable = Callable()


func setup(
	desk: DeskView, market: bool, sheet: DeckSheet, slip: DetailSlip, busy: Callable
) -> void:
	_desk = desk
	_market = market
	_sheet = sheet
	_slip = slip
	_screen_busy = busy
	BuyTicket.readable(ticket)
	ticket.custom_minimum_size = Vector2.ZERO
	ticket.pressed.connect(_choose)
	ticket.mouse_entered.connect(_describe)
	ticket.focus_entered.connect(_describe)
	ticket.mouse_exited.connect(_slip.hide_for.bind(ticket))
	ticket.focus_exited.connect(_slip.hide_for.bind(ticket))


## Shows the ticket as the desk stands: offered, done this visit, or gone.
func show_offer() -> void:
	ticket.visible = _desk.is_open()
	if not ticket.visible:
		return
	var values: Dictionary[String, Variant] = {"mark": _mark(), "price": _desk.price()}
	var key: String = "desk.ticket.stamp" if _desk.stamps() else "desk.ticket"
	if _desk.used():
		key = "desk.used.stamp" if _desk.stamps() else "desk.used"
	ticket.text = TranslationServer.translate(key).format(values)
	ticket.disabled = not _desk.affordable()


func _mark() -> String:
	return TranslationServer.translate("keyword.%s.name" % _desk.offer())


func _describe() -> void:
	var stamps: bool = _desk.stamps()
	var title: String = TranslationServer.translate("desk.stamp") if stamps else _mark()
	var rule: String = TranslationServer.translate(
		"desk.rule.stamp" if stamps else "desk.rule.mark"
	)
	_slip.show_for(ticket, title, rule.format({"mark": _mark()}))


func _choose() -> void:
	if _screen_busy.is_valid() and _screen_busy.call():
		return
	_slip.hide_slip()
	_sheet.open_desk(_desk, _market)

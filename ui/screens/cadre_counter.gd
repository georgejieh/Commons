class_name CadreCounter
extends RefCounted
## The Cadres on a shop's counter: three cards (StoreCard) bought with coupons, the state
## store's sealed Approved in red, the black market's Paid in black. A purchase is acted
## out over the page: the coupons roll down, the card is sealed, then it shrinks away to
## its place on the board. Reduced motion skips to the result. A black market Cadre that
## needs a rank asks for one over the counter first (ADR 0021). Every purchase goes
## through the run controller.

## Coupons were paid for a card that is now being acted out: the page rolls them down.
signal paid
## A purchase is over: the page shows the run again, and the card's place on the board
## swells, when slot is one.
signal settled(slot: int)

## The width the seal is printed at, in pixels.
const SEAL_WIDTH: float = 250.0
## Seconds the seal sits on a bought card, and the card takes to reach the board.
const SEAL_HOLD: float = 0.42
## Seconds a bought card takes to shrink to its place on the board.
const PIN_TIME: float = 0.3
## The scale a bought card shrinks to on its way to the board.
const PIN_SCALE: float = 0.3
## Pixels between the cards on the counter.
const GAP: int = 28

## The counter's cards, for the page to place.
var row: HBoxContainer = HBoxContainer.new()
## The seal pressed on a bought card; it stands over the page.
var seal: InkSeal = InkSeal.new()
## The question of a rank that a black market Cadre asks over the counter; it stands over the page.
var picker: RankPicker = RankPicker.new()

var _shop: StallContext
var _board: NoticeBoard
## The page the act plays over.
var _host: Control
## True while a purchase is being acted out: the counter takes no second one.
var _busy: bool = false


## Sets the counter up for shop, flying what is bought to board over host.
func setup(shop: StallContext, board: NoticeBoard, host: Control) -> void:
	_shop = shop
	_board = board
	_host = host
	row.add_theme_constant_override("separation", GAP)
	var word: String = tr("market.paid" if shop.market else "store.approved")
	seal.prepare(word, _ink(), SEAL_WIDTH)


## True while a purchase is being acted out or a rank is asked.
func is_busy() -> bool:
	return _busy or picker.is_open()


## True while a purchase is being acted out, for tests.
func is_buying() -> bool:
	return _busy


## Lays out the counter's stock, or says it is empty.
func show_stock() -> void:
	ScreenKit.clear(row)
	var stock: Array[String] = _shop.desk.stock()
	for slot: int in stock.size():
		var buy: Callable = func(panel: Control) -> void: _buy(slot, panel)
		var card: Control = StoreCard.make(
			_shop.controller, _shop.desk, slot, stock[slot], _shop.slip, buy, _ink()
		)
		row.add_child(card)
	if stock.is_empty():
		var empty: Label = ScreenKit.styled(tr("market.empty"), CommonsTheme.TITLE)
		empty.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(StoreNotes.on_paper(empty))


## The ink the counter seals in: the state store's red, the black market's black.
func _ink() -> Color:
	return ScreenKit.INK if _shop.market else ScreenKit.RED


## Buys the Cadre in a slot and acts it out.
func _buy(slot: int, panel: Control, rank: int = Ranks.INVALID) -> void:
	if _shop.busy.call() or (rank == Ranks.INVALID and not _shop.app.arrival.attempt("buy", slot)):
		return
	var controller: RunController = _shop.controller
	var desk: ShopDesk = _shop.desk
	if rank == Ranks.INVALID and _shop.market and controller.items.needs_rank(desk.stock()[slot]):
		var name: String = tr("modifier.%s.name" % desk.stock()[slot])
		var then: Callable = func(picked: int) -> void: _buy(slot, panel, picked)
		picker.ask(tr("store.pick_rank").format({"name": name}), panel, then)
		return
	var held: int = controller.run.held_cadres().size()
	if _shop.market:
		controller.market_buy(slot, rank)
	else:
		controller.buy(slot)
	if controller.run.held_cadres().size() == held:
		settled.emit(-1)
		return
	Audio.play(AudioEvents.STORE_BUY)
	_shop.slip.hide_for(panel)
	if UiMotion.reduced():
		settled.emit(-1)
		return
	_busy = true
	paid.emit()
	_fly(panel, held)


## The card is sealed, then shrinks away to the board's place for it.
func _fly(panel: Control, place: int) -> void:
	var middle: Vector2 = panel.global_position + panel.size / 2.0
	seal.position = middle - _host.global_position - seal.size / 2.0
	_host.move_child(seal, -1)
	seal.press()
	panel.z_index = ScreenKit.LAYER_LIFTED
	var to: Vector2 = panel.position + _board.slot_center(place) - middle
	var tween: Tween = _host.create_tween()
	tween.tween_interval(SEAL_HOLD)
	tween.tween_callback(seal.hide)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position", to, PIN_TIME)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE * PIN_SCALE, PIN_TIME)
	tween.tween_callback(_pinned.bind(place))


## The bought card has reached the board: the counter shows the gap, the board the card.
func _pinned(place: int) -> void:
	_busy = false
	settled.emit(place)

class_name StoreScreen
extends Control
## A shop between Sets: Cadres on the counter, bought with coupons, a reroll, and what
## you already hold, pinned on a board. With market set it is the black market behind the
## state store: the room goes dark, prices are higher, the plot can be enlarged, and every
## purchase adds Resentment, which the screen counts. Every purchase and every sale of a
## held Cadre or Campaign (SellDesk, ADR 0040) goes through the run controller. The page
## fits one 1920x1080 screen in four rows: the heading, with your coupons, the shop's note
## and the Reforms in force; the Cadre cards (CadreCounter) beside the Directives or the
## plot's cards; the buttons; and your board beside "On the counter", whose compact papers
## show their rules in one shared DetailSlip. All text sits on paper. Each piece is a stall
## set up with the page's StallContext; a bought envelope opens over the page.

## Modifier names are long, so they print a step below the title size (the set intro's
## debuff card uses it).
const NAME_SIZE: int = 32
## The black market is the store after dark, sealed in black ink.
const NIGHT: Color = Color(0.36, 0.34, 0.46)
const NIGHT_SHADE: Color = Color(0.03, 0.02, 0.09, 0.62)
## A card on the counter, the same in both shops.
const CARD: Vector2 = Vector2(360, 470)
## The page's rows sit closer than other pages', so four of them fit 1080.
const ROW_GAP: int = 14
## Between the heading's pieces, close enough to leave the notes and all six Reforms room.
const HEADER_GAP: int = 40
const MAIN_GAP: int = 24
const SHELF_GAP: int = 20
## The most room the Cadre board takes; its cards shrink to fit six.
const BOARD_BOX: Vector2 = Vector2(612, 122)
## Inside the paper's printed border, which ends 17 px in.
const SHEET_PADDING: int = 20

## True for the black market. Set on the scene.
@export var market: bool = false

## The Cadres on the counter, with the seal pressed on one bought and the rank it asks.
var cadres: CadreCounter = CadreCounter.new()
## The coupons the player holds, in the heading.
var coupons: Label = ScreenKit.styled("", CommonsTheme.TITLE)
## The player's Cadres, pinned on the board at the foot of the page.
var board: NoticeBoard = NoticeBoard.new()
## The black market's Resentment count; the state store has none.
var resentment: Label = null
## The black market's plot cards and upgrades; the state store has none.
var goods: MarketGoods = null
## Rerolls the Cadres on the counter, at the price it shows.
var reroll: Button = ScreenKit.button("", CommonsTheme.GHOST)
## The state store's Directives beside its Cadres; the black market has none.
var directives: DirectiveRow = null
## The state store's cards for the communal deck (ADR 0042); the black market has none.
var deck_goods: DeckGoods = null
## The Campaign on the counter, and the tray of those held.
var campaign_stall: CampaignStall = CampaignStall.new()
## The Reform on the counter, and the strip of those in force.
var reform_stall: ReformStall = ReformStall.new()
## Explains what is hovered or focused on the counter, the board and the strip.
var slip: DetailSlip = DetailSlip.new()
## The envelope on the counter, and the envelope opened over the page (ADR 0021).
var envelope_stall: EnvelopeStall = EnvelopeStall.new()
## Sells back the held Cadres and Campaigns (ADR 0040).
var sale: SellDesk = SellDesk.new()
## The whole deck and the plot, with their marks (ADR 0041).
var deck: DeckSheet = DeckSheet.new()
## The desk that marks a deck card (ADR 0041): its ticket is in the state store's row of
## buttons, and under the black market's plot stall.
var desk_stall: DeskStall = DeskStall.new()
## The household's true figures, shown only at the stage past the last (ADR 0022).
var books: SmallLedger = SmallLedger.new(2)
var _app: App
## What every stall on the page is set up with.
var _shop: StallContext
var _shown_resentment: float = 0.0
var _shown_coupons: float = 0.0
## The page's main blocks by name, for the layout test.
var _blocks: Dictionary[String, Control] = {}
## The page's first button, which leaves or goes back, and the state store's door to the
## black market.
var _leave_button: Button
var _door: Button = null


## Cancel (Escape, or B on a pad) goes back from the black market, as Back does.
func _unhandled_input(event: InputEvent) -> void:
	if market and ScreenKit.take_cancel(self, event):
		_back()


func open(app: App) -> void:
	_app = app
	slip.quiet = app.arrival.is_running
	_shop = StallContext.new(app, market, slip, deck, is_issuing)
	var shade: Color = NIGHT_SHADE if market else ScreenKit.SHADE
	var tint: Color = NIGHT if market else Color.WHITE
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.store, shade, tint)
	column.add_theme_constant_override("separation", ROW_GAP)
	_set_up_stalls()
	column.add_child(_header_row(app))
	column.add_child(_main_row())
	column.add_child(_button_row())
	column.add_child(_bottom_row())
	add_child(cadres.seal)
	add_child(cadres.picker)
	add_child(slip)
	add_child(deck)
	deck.setup(app.controller)
	deck.closed.connect(_on_deck_closed)
	deck.chosen.connect(_on_chosen)
	desk_stall.setup(_shop)
	_shown_coupons = app.controller.run.coupons()
	_shown_resentment = app.controller.run.resentment()
	refresh()
	ScreenKit.reveal(column)
	ScarceStamp.press_under(cadres.row, UiMotion.PRESETS.scarce_wait)
	_leave_button.grab_focus()
	# An envelope left open, as by a save taken while choosing, is shown open again.
	envelope_stall.resume()


## The page's main blocks by name, each a rectangle that must fit the screen without
## overlapping another: heading, notes, counter, side, buttons, board and shelf.
func blocks() -> Dictionary[String, Control]:
	return _blocks.duplicate()


## What the arrival points at here (ADR 0026): the first Cadre, the door, a plot card.
func tutorial_target(key: String) -> Control:
	match key:
		"buy":
			return cadres.row.get_child(0) if cadres.row.get_child_count() > 0 else null
		"door":
			return _door
		"plot_card":
			return null if goods == null else goods.card_button(0)
	return null


## True while any purchase, issue or enactment is being acted out, or a rank is asked.
func is_issuing() -> bool:
	var directing: bool = directives != null and directives.is_busy()
	var stalls: bool = campaign_stall.is_busy() or reform_stall.is_busy()
	stalls = stalls or envelope_stall.is_busy() or cadres.is_busy()
	return stalls or directing or deck.is_open()


## Shows the run as it is now: the coupons, every stall's offers and the board.
func refresh() -> void:
	var controller: RunController = _app.controller
	var state: RunView = controller.run
	UiMotion.count(coupons, _shown_coupons, state.coupons(), StoreNotes.coupon_text)
	_shown_coupons = state.coupons()
	cadres.show_stock()
	reroll.text = tr("store.reroll").format({"price": _shop.desk.reroll_price()})
	reroll.disabled = not _shop.desk.can_reroll()
	books.show_shop(state)
	if market:
		_shown_resentment = StoreNotes.count_resentment(resentment, _shown_resentment, state)
		goods.refresh()
	else:
		directives.show_offers()
		deck_goods.refresh()
	board.show_cadres(controller)
	campaign_stall.show_offer()
	reform_stall.show_offer()
	envelope_stall.show_offer()
	desk_stall.show_offer()
	sale.refresh()


## The stalls every shop has, each reporting back to the page.
func _set_up_stalls() -> void:
	cadres.setup(_shop, board, self)
	cadres.paid.connect(_roll_coupons)
	cadres.settled.connect(_on_cadre_settled)
	campaign_stall.setup(_shop)
	campaign_stall.spent.connect(_on_spent)
	reform_stall.setup(_shop)
	reform_stall.spent.connect(_on_spent)
	envelope_stall.setup(_shop, self)
	envelope_stall.spent.connect(_on_spent)
	envelope_stall.settled.connect(_on_envelope_settled)
	board.setup(_shop.controller.figures.cadre_slots(), BOARD_BOX)
	board.empty_line = tr("store.shelf.empty")
	sale.setup(_shop, board, campaign_stall.tray)
	sale.sold.connect(_on_sold)


func _header_row(app: App) -> Control:
	var place: String = "market" if market else "store"
	var heading: Control = ScreenKit.header(tr(place + ".eyebrow"), tr(place + ".title"))
	var top: Array[Control] = [heading, StoreNotes.balance(coupons, books)]
	if market:
		resentment = ScreenKit.styled("", CommonsTheme.TITLE)
		top.append(StoreNotes.resentment_box(resentment))
	var notes: VBoxContainer = StoreNotes.beside(app.controller, market, reform_stall.strip)
	top.append(notes)
	_blocks["heading"] = heading
	_blocks["notes"] = notes
	return ScreenKit.row(top, HEADER_GAP)


func _main_row() -> Control:
	var side: Control
	if market:
		goods = MarketGoods.new()
		goods.setup(_shop)
		goods.spent.connect(refresh)
		var stall: Control = goods.panel()
		stall.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
		# The black market's row of buttons is full with its upgrades, so its desk's
		# ticket stands under the plot stall.
		side = VBoxContainer.new()
		side.add_child(stall)
		side.add_child(desk_stall.ticket)
	else:
		directives = DirectiveRow.new()
		directives.setup(_shop)
		directives.spent.connect(_on_spent)
		directives.settled.connect(refresh)
		side = directives
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_blocks["counter"] = cadres.row
	_blocks["side"] = side
	return ScreenKit.row([cadres.row, side], MAIN_GAP)


## The leave, reroll and door buttons, or the black market's upgrade tickets.
func _button_row() -> Control:
	reroll.pressed.connect(_on_reroll)
	BuyTicket.readable(reroll)
	_leave_button = ScreenKit.button(
		tr("market.back" if market else "store.leave"), CommonsTheme.PRIMARY
	)
	var deck_button: Button = ScreenKit.button(tr("deck.open"), CommonsTheme.GHOST)
	deck_button.tooltip_text = tr("deck.open_tip")
	# The Deck button and the desk's ticket are as wide as their words, so the black
	# market's row keeps its upgrades.
	deck_button.custom_minimum_size = Vector2.ZERO
	deck_button.pressed.connect(_open_deck)
	var buttons: HBoxContainer
	if market:
		_leave_button.pressed.connect(_back)
		buttons = ScreenKit.row([_leave_button, reroll, goods.upgrades, deck_button])
	else:
		_leave_button.pressed.connect(_leave)
		_door = ScreenKit.button(tr("market.open"), CommonsTheme.GHOST)
		_door.pressed.connect(_to_market)
		deck_goods = DeckGoods.new()
		deck_goods.setup(_shop)
		var row: Array[Control] = [
			_leave_button, reroll, _door, deck_button, desk_stall.ticket, deck_goods.strip
		]
		buttons = ScreenKit.row(row)
	_blocks["buttons"] = buttons
	return buttons


## Your board on the left, and what is on the counter on the right.
func _bottom_row() -> Control:
	var held: VBoxContainer = VBoxContainer.new()
	held.add_theme_constant_override("separation", 4)
	held.add_child(ScreenKit.eyebrow(tr("store.shelf")))
	held.add_child(board)
	var own: PanelContainer = _sheet(ScreenKit.row([held, campaign_stall.tray], SHELF_GAP))
	var offers: Array[Control] = _offers()
	var on_counter: VBoxContainer = VBoxContainer.new()
	on_counter.add_theme_constant_override("separation", 4)
	on_counter.add_child(ScreenKit.eyebrow(tr("store.counter")))
	on_counter.add_child(ScreenKit.row(offers, 12))
	var shelf: PanelContainer = _sheet(on_counter)
	# The counter keeps to the right edge, whatever room the board leaves it.
	shelf.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	_blocks["board"] = own
	_blocks["shelf"] = shelf
	return ScreenKit.row([own, shelf], SHELF_GAP)


## The offers "On the counter": the Campaign's, the Reform's and the envelope's.
func _offers() -> Array[Control]:
	return [campaign_stall.offers, reform_stall.offers, envelope_stall.offers]


func _sheet(content: Control) -> PanelContainer:
	var sheet: PanelContainer = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
	sheet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sheet.add_child(content)
	return sheet


## A Cadre's purchase is over: the page shows the run, and the card's place on the board
## swells once the card has flown there.
func _on_cadre_settled(slot: int) -> void:
	refresh()
	if slot >= 0:
		board.pulse_slot(slot)


## The coupons roll down to what the run holds now, and the count swells.
func _roll_coupons() -> void:
	var held: int = _app.controller.run.coupons()
	UiMotion.count(coupons, _shown_coupons, held, StoreNotes.coupon_text)
	_shown_coupons = held
	UiMotion.pulse(coupons)


## Coupons were paid elsewhere on the page: they roll down while the purchase plays.
func _on_spent() -> void:
	_roll_coupons()
	reroll.disabled = not _shop.desk.can_reroll()
	books.show_shop(_app.controller.run)


## Something held was sold back: the coupons count up, and the freed place swells.
func _on_sold(campaign: bool) -> void:
	_on_spent()
	refresh()
	if not campaign:
		board.pulse_slot(_app.controller.run.held_cadres().size())
	if get_viewport().gui_get_focus_owner() == null:
		_leave_button.grab_focus()


func _on_reroll() -> void:
	# A reroll frees the counter's cards, so it waits for a purchase being acted out.
	if is_issuing() or not _app.arrival.attempt("reroll"):
		return
	if market:
		_app.controller.market_reroll()
	else:
		_app.controller.reroll()
	slip.hide_slip()
	refresh()
	var fresh: Array[Control] = []
	for child: Node in cadres.row.get_children():
		fresh.append(child as Control)
	var shelves: Array[Node] = []
	shelves.assign(_offers())
	if directives != null:
		shelves.append(directives)
	for shelf: Node in shelves:
		for child: Node in shelf.get_children():
			if child is PanelContainer:
				fresh.append(child as Control)
	UiMotion.enter(fresh)
	ScarceStamp.press_under(cadres.row, UiMotion.PRESETS.scarce_wait)


## The deck sheet, read-only, over the page.
func _open_deck() -> void:
	if not is_issuing():
		slip.hide_slip()
		deck.open_deck()


## Back to the page's first button, unless the sheet stood over an open envelope, which
## takes the focus back itself.
func _on_deck_closed() -> void:
	if not envelope_stall.is_busy():
		_leave_button.grab_focus()


## The desk marked a card, or a card came into the deck: the coupons count down and the
## paper says it is done.
func _on_chosen(_card_id: int) -> void:
	# A deck card kept from an envelope sounds as the envelope acts it out.
	if not envelope_stall.is_busy():
		Audio.play(AudioEvents.STORE_BUY)
	_on_spent()
	refresh()


## An envelope was answered: the page shows what it gave, wherever that went.
func _on_envelope_settled() -> void:
	refresh()
	_leave_button.grab_focus()


## Back to the state store, and through the door to the black market, once nothing is
## being acted out or chosen.
func _back() -> void:
	if not is_issuing() and _app.arrival.attempt("back"):
		_app.back()


func _to_market() -> void:
	if not is_issuing() and _app.arrival.attempt("door"):
		_app.show_screen("black_market")


## Leaves the store for the next Quota, once nothing is being acted out or chosen.
func _leave() -> void:
	if is_issuing() or not _app.arrival.attempt("leave"):
		return
	_app.controller.leave_store()
	_app.show_screen("set_intro", true)

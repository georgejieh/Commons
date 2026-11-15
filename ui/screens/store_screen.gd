class_name StoreScreen
extends Control
## A shop between Sets (P4.10): Cadres on the counter, bought with coupons, a reroll,
## and what you already hold, pinned on a board. The same screen is the state store and,
## with market set, the black market behind it: the room goes dark, prices are higher,
## the plot can be enlarged, and every purchase adds Resentment, which the screen
## counts. Every purchase goes through the run controller. A purchase is acted out: the
## card is sealed, then flies down to its place on your board.
##
## The page fits one 1920x1080 screen in four rows inside the header's margins:
## - the heading, with your coupons, the shop's note and the Reforms in force at its right;
## - the three Cadre cards, which set the row's height, beside the state store's
##   Directives or the black market's cards for the plot;
## - the buttons;
## - your board (Cadres and held Campaigns), and "On the counter": a Campaign, the state
##   store's Reform, and a place kept for an envelope, each a compact paper whose full
##   rules show in one shared DetailSlip. All text sits on paper.

## Modifier names are long, so they print a step below the title size (the set intro's
## debuff card uses it).
const NAME_SIZE: int = 32
const SEAL_WIDTH: float = 250.0
## Seconds the seal sits on a bought card, and the card takes to reach the board.
const SEAL_HOLD: float = 0.42
const PIN_TIME: float = 0.3
const PIN_SCALE: float = 0.3
## The black market is the store after dark, sealed in black ink.
const NIGHT: Color = Color(0.36, 0.34, 0.46)
const NIGHT_SHADE: Color = Color(0.03, 0.02, 0.09, 0.62)
## A card on the counter, the same in both shops.
const CARD: Vector2 = Vector2(360, 470)
const MARKET_INK: Color = Color("1e1a16")
## The page's rows sit closer than other pages', so four of them fit 1080.
const ROW_GAP: int = 14
## Between the heading's pieces, close enough to leave the notes and all six Reforms room.
const HEADER_GAP: int = 40
const MAIN_GAP: int = 24
const SHELF_GAP: int = 20
## The most room the Cadre board takes; its cards shrink to fit six.
const BOARD_BOX: Vector2 = Vector2(640, 122)
const SHEET_PADDING: int = 8
## The warning's width at the right of the black market's heading.
const NOTE_WIDTH: float = 640.0

## True for the black market. Set on the scene.
@export var market: bool = false

var _app: DemoApp
var _counter: HBoxContainer = HBoxContainer.new()
var _coupons: Label = ScreenKit.styled("", CommonsTheme.TITLE)
var _board: NoticeBoard = NoticeBoard.new()
var _seal: InkSeal = InkSeal.new()
## True while a purchase is being acted out: the counter takes no second one.
var _busy: bool = false
var _desk: ShopDesk
## The black market's Resentment count, plot cards and upgrades; the state store has none.
var _resentment: Label = null
var _shown_resentment: float = 0.0
var _goods: MarketGoods = null
var _upgrades: HBoxContainer = null
var _reroll: Button = ScreenKit.button("", CommonsTheme.GHOST)
var _shown_coupons: float = 0.0
## The state store's Directives; the black market issues none.
var _directives: DirectiveRow = null
var _campaign_stall: CampaignStall = CampaignStall.new()
var _reform_stall: ReformStall = ReformStall.new()
## Explains what is hovered or focused on the counter, the board and the strip.
var _slip: DetailSlip = DetailSlip.new()
## Kept for the envelope offer (P4.11g): sized, with nothing in it yet.
var _envelope: Control = Control.new()
## Asks for a rank before a Cadre that needs one is bought (ADR 0021).
var _picker: RankPicker = RankPicker.new()
## The page's main blocks by name, for the layout test.
var _blocks: Dictionary[String, Control] = {}


func open(app: DemoApp) -> void:
	_app = app
	_desk = app.controller.desk(market)
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.store)
	column.add_theme_constant_override("separation", ROW_GAP)
	if market:
		# The backdrop is the page's first child, the shade its second: deepened to night.
		(get_child(0) as Control).modulate = NIGHT
		(get_child(1) as ColorRect).color = NIGHT_SHADE
	_campaign_stall.setup(app, market, is_issuing, _slip)
	_campaign_stall.spent.connect(_on_spent)
	_reform_stall.setup(app, _slip, is_issuing, not market)
	_reform_stall.spent.connect(_on_spent)
	_board.setup(app.controller.cadre_slots(), BOARD_BOX)
	column.add_child(_header_row(app))
	column.add_child(_main_row(app))
	var leave: Button = _button_row(app, column)
	column.add_child(_bottom_row())
	var word: String = tr("market.paid" if market else "store.approved")
	_seal.prepare(word, MARKET_INK if market else ScreenKit.RED, SEAL_WIDTH)
	add_child(_seal)
	add_child(_picker)
	add_child(_slip)
	_shown_coupons = app.controller.state_copy().coupons
	_shown_resentment = app.controller.state_copy().resentment
	_refresh()
	ScreenKit.reveal(column)
	leave.grab_focus()


## The page's main blocks by name, each a rectangle that must fit the screen without
## overlapping another: heading, notes, counter, side, buttons, board and shelf.
func blocks() -> Dictionary[String, Control]:
	return _blocks.duplicate()


## The shared slip, for tests.
func slip() -> DetailSlip:
	return _slip


func _header_row(app: DemoApp) -> Control:
	var place: String = "market" if market else "store"
	var heading: Control = ScreenKit.header(tr(place + ".eyebrow"), tr(place + ".title"))
	var balance: VBoxContainer = VBoxContainer.new()
	balance.add_child(ScreenKit.eyebrow(tr("store.balance")))
	_coupons.add_theme_color_override("font_color", ScreenKit.COUPON)
	_coupons.autowrap_mode = TextServer.AUTOWRAP_OFF
	balance.add_child(_coupons)
	balance.size_flags_vertical = Control.SIZE_SHRINK_END
	var top: Array[Control] = [heading, balance]
	if market:
		top.append(_resentment_box())
	var notes: VBoxContainer = VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.alignment = BoxContainer.ALIGNMENT_END
	notes.add_theme_constant_override("separation", 8)
	if market:
		notes.add_child(StoreNotes.warning(app.controller, NOTE_WIDTH))
	elif app.controller.is_rationed():
		notes.add_child(StoreNotes.rationing(app.controller))
	notes.add_child(_reform_stall.strip)
	top.append(notes)
	_blocks["heading"] = heading
	_blocks["notes"] = notes
	return ScreenKit.row(top, HEADER_GAP)


func _main_row(app: DemoApp) -> Control:
	_counter.add_theme_constant_override("separation", 28)
	var side: Control
	if market:
		_goods = MarketGoods.new()
		_goods.setup(app.controller, _desk, _market_buy)
		side = _goods.panel()
		side.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING + 2))
		_upgrades = _goods.upgrades
	else:
		_directives = DirectiveRow.new()
		_directives.setup(app.controller, _desk, is_issuing)
		_directives.spent.connect(_on_spent)
		_directives.settled.connect(_refresh)
		side = _directives
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_blocks["counter"] = _counter
	_blocks["side"] = side
	return ScreenKit.row([_counter, side], MAIN_GAP)


## The leave, reroll and door buttons, or the black market's upgrade tickets. Returns the
## button that takes focus first.
func _button_row(app: DemoApp, column: VBoxContainer) -> Button:
	_reroll.pressed.connect(_on_reroll)
	var leave: Button = ScreenKit.button(
		tr("market.back" if market else "store.leave"), CommonsTheme.PRIMARY
	)
	var buttons: HBoxContainer
	if market:
		leave.pressed.connect(app.back)
		buttons = ScreenKit.row([leave, _reroll, _upgrades])
	else:
		leave.pressed.connect(_leave)
		var door: Button = ScreenKit.button(tr("market.open"), CommonsTheme.GHOST)
		door.pressed.connect(func() -> void: app.show_screen("black_market"))
		buttons = ScreenKit.row([leave, _reroll, door])
	_blocks["buttons"] = buttons
	column.add_child(buttons)
	return leave


## Your board on the left, and what is on the counter on the right.
func _bottom_row() -> Control:
	var cadres: VBoxContainer = VBoxContainer.new()
	cadres.add_theme_constant_override("separation", 4)
	cadres.add_child(ScreenKit.eyebrow(tr("store.shelf")))
	cadres.add_child(_board)
	var board: PanelContainer = _sheet(ScreenKit.row([cadres, _campaign_stall.tray], SHELF_GAP))
	_envelope.custom_minimum_size = CounterPanel.SIZE
	_envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var offers: Array[Control] = [_campaign_stall.offers(), _reform_stall.offers, _envelope]
	var on_counter: VBoxContainer = VBoxContainer.new()
	on_counter.add_theme_constant_override("separation", 4)
	on_counter.add_child(ScreenKit.eyebrow(tr("store.counter")))
	on_counter.add_child(ScreenKit.row(offers, 12))
	var shelf: PanelContainer = _sheet(on_counter)
	# The counter keeps to the right edge, whatever room the board leaves it.
	shelf.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	_blocks["board"] = board
	_blocks["shelf"] = shelf
	return ScreenKit.row([board, shelf], SHELF_GAP)


func _sheet(content: Control) -> PanelContainer:
	var sheet: PanelContainer = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(SHEET_PADDING))
	sheet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sheet.add_child(content)
	return sheet


func _refresh() -> void:
	var controller: RunController = _app.controller
	var state: RunState = controller.state_copy()
	UiMotion.count(_coupons, _shown_coupons, state.coupons, _coupon_text)
	_shown_coupons = state.coupons
	for child: Node in _counter.get_children():
		_counter.remove_child(child)
		child.queue_free()
	var stock: Array[String] = _desk.stock()
	for slot: int in stock.size():
		_counter.add_child(_item(slot, stock[slot]))
	if stock.is_empty():
		var empty: Label = ScreenKit.styled(tr("market.empty"), CommonsTheme.TITLE)
		empty.autowrap_mode = TextServer.AUTOWRAP_OFF
		_counter.add_child(StoreNotes.on_paper(empty))
	_reroll.text = tr("store.reroll").format({"price": _desk.reroll_price()})
	_reroll.disabled = not _desk.can_reroll()
	if market:
		UiMotion.count(_resentment, _shown_resentment, state.resentment, _resentment_text)
		if state.resentment > _shown_resentment:
			UiMotion.pulse(_resentment)
		_shown_resentment = state.resentment
		_goods.refresh()
	else:
		_directives.show_offers()
	_board.show_cadres(controller)
	_campaign_stall.show_offer()
	_reform_stall.show_offer()


func _item(slot: int, cadre_id: String) -> Control:
	var buy: Callable = func(panel: Control) -> void: _buy(slot, panel)
	return StoreCard.make(_app.controller, _desk, slot, cadre_id, _slip, buy)


## Buys the Cadre in a slot and acts it out: the coupons roll down, the card is sealed,
## then it shrinks away to its place on the board. Reduced motion skips to the result. A
## Cadre that needs a rank asks for one over the counter first.
func _buy(slot: int, panel: Control, rank: int = Ranks.INVALID) -> void:
	if is_issuing():
		return
	var controller: RunController = _app.controller
	if rank == Ranks.INVALID and market and controller.needs_rank(_desk.stock()[slot]):
		var name: String = tr("modifier.%s.name" % _desk.stock()[slot])
		var then: Callable = func(picked: int) -> void: _buy(slot, panel, picked)
		_picker.ask(tr("store.pick_rank").format({"name": name}), _counter, then)
		return
	var held: int = controller.state_copy().inventory.cadres.size()
	if market:
		controller.market_buy(slot, rank)
	else:
		controller.buy(slot)
	var state: RunState = controller.state_copy()
	if state.inventory.cadres.size() == held:
		_refresh()
		return
	Audio.play(AudioEvents.STORE_BUY)
	_slip.hide_for(panel)
	if UiMotion.reduced():
		_refresh()
		return
	_busy = true
	UiMotion.count(_coupons, _shown_coupons, state.coupons, _coupon_text)
	_shown_coupons = state.coupons
	UiMotion.pulse(_coupons)
	var middle: Vector2 = panel.global_position + panel.size / 2.0
	_seal.position = middle - global_position - _seal.size / 2.0
	move_child(_seal, -1)
	_seal.press()
	panel.z_index = 1
	var to: Vector2 = panel.position + _board.slot_center(held) - middle
	var tween: Tween = create_tween()
	tween.tween_interval(SEAL_HOLD)
	tween.tween_callback(_seal.hide)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "position", to, PIN_TIME)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE * PIN_SCALE, PIN_TIME)
	tween.tween_callback(_pinned.bind(held))


## The bought card has reached the board: the counter shows the gap, the board the card.
func _pinned(slot: int) -> void:
	_busy = false
	_refresh()
	_board.pulse_slot(slot)


## True while a purchase is being acted out, for tests.
func is_buying() -> bool:
	return _busy


## True while any purchase, issue or enactment is being acted out, or a rank is asked.
func is_issuing() -> bool:
	var directing: bool = _directives != null and _directives.is_busy()
	var stalls: bool = _campaign_stall.is_busy() or _reform_stall.is_busy()
	return _busy or _picker.is_open() or stalls or directing


## Coupons were paid elsewhere on the page: they roll down while the purchase plays.
func _on_spent() -> void:
	var coupons: int = _app.controller.state_copy().coupons
	UiMotion.count(_coupons, _shown_coupons, coupons, _coupon_text)
	_shown_coupons = coupons
	UiMotion.pulse(_coupons)
	_reroll.disabled = not _desk.can_reroll()


func _resentment_box() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_child(ScreenKit.eyebrow(tr("keyword.resentment.name")))
	_resentment = ScreenKit.styled("", CommonsTheme.TITLE)
	_resentment.add_theme_color_override("font_color", ScreenKit.RED)
	_resentment.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(_resentment)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	return box


func _resentment_text(value: float) -> String:
	return str(roundi(value))


## A plot card or an upgrade from the black market, bought by act.
func _market_buy(act: Callable) -> void:
	if is_issuing():
		return
	act.call()
	Audio.play(AudioEvents.STORE_BUY)
	_refresh()


func _on_reroll() -> void:
	# A reroll frees the counter's cards, so it waits for a purchase being acted out.
	if is_issuing():
		return
	if market:
		_app.controller.market_reroll()
	else:
		_app.controller.reroll()
	_slip.hide_slip()
	_refresh()
	var fresh: Array[Control] = []
	for child: Node in _counter.get_children():
		fresh.append(child as Control)
	var shelves: Array[Node] = [_campaign_stall.offers(), _reform_stall.offers]
	if _directives != null:
		shelves.append(_directives)
	for shelf: Node in shelves:
		for child: Node in shelf.get_children():
			if child is PanelContainer:
				fresh.append(child as Control)
	UiMotion.enter(fresh)


## Leaves the store for the next Quota.
func _leave() -> void:
	_app.controller.leave_store()
	_app.show_screen("set_intro", true)


func _coupon_text(value: float) -> String:
	return Strings.count("store.coupons", roundi(value))

extends RefCounted
## The playtest's frames of marks on deck cards (ADR 0041), with real clicks. In the state
## store the Deck button opens the deck sheet (deck_sheet) and Close shuts it; the desk's
## ticket opens it again to choose, a click picks the first card the desk
## would mark (deck_choose), the confirm marks it, and the Deck button shows the deck with
## the new mark (deck_marked). The deck stall's first card is bought (deck_stall), a click
## picks the first deck card it may replace (deck_exchange_choose), the confirm makes the
## exchange, and the Deck button shows the deck with the card in (deck_exchanged), ADR
## 0042. At the table the player's first four cards take Model, Sheaf, Pennant and Surplus
## through the run's own path for a mark, and the hand is photographed with all four
## (marks_hand); the marks stay for the rest of the walk. After the exchange the Deck key
## opens the sheet over the table (deck_table) and Cancel shuts it.
## Loaded at run time by playtest.gd, so it reaches every UI node as Object, Node or
## Control, never by a ui/ class name. Development only; tools/ never ships.

const SETTLE_SECONDS: float = 1.8
const WAIT_SECONDS: float = 10.0
## Where on a fanned card a click lands, in its own pixels: on the strip the next card
## leaves showing.
const CARD_SPOT: Vector2 = Vector2(14.0, 84.0)

var shots: int = 0
var misclicks: int = 0
## True once the walk made an exchange at the state store.
var exchanged: bool = false

var _tree: SceneTree
var _app: Node
var _out: String
var _headless: bool


func _init(tree: SceneTree, app: Node, out: String, headless: bool, shot_count: int) -> void:
	_tree = tree
	_app = app
	_out = out
	_headless = headless
	shots = shot_count


## The deck sheet read-only, then one use of the state store's desk, from the store.
func store() -> void:
	var switcher: Object = _app.get("switcher")
	var screen: Node = switcher.call("current")
	var sheet: Object = screen.get("_deck")
	await _press(_button(screen, TranslationServer.translate("deck.open")))
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_fail("deck sheet did not open")
		return
	await _shot("deck_sheet")
	await _press(sheet.call("back_button"))
	if bool(sheet.call("is_open")):
		_fail("deck sheet did not close")
		return
	await _desk(screen, sheet)
	await _exchange(screen, sheet)


func _desk(screen: Node, sheet: Object) -> void:
	var controller: Object = _app.get("controller")
	var desk: Object = controller.call("mark_desk", false)
	await _afford(screen, int(desk.call("price")))
	var stall: Object = screen.get("_desk_stall")
	var ticket: Button = stall.get("ticket")
	if ticket == null or not ticket.is_visible_in_tree() or ticket.disabled:
		print("NO BUTTON desk")
		return
	await _press(ticket)
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_fail("desk did not open the deck sheet")
		return
	var board: Object = sheet.call("board")
	var chosen: int = -1
	for card_id: int in board.call("card_ids"):
		if not bool(board.call("is_plot", card_id)) and desk.call("refusal", card_id) == "":
			chosen = card_id
			break
	var view: Control = board.call("view_of", chosen)
	await _mouse_click(view.get_global_transform_with_canvas() * CARD_SPOT)
	if int(board.get("picked")) != chosen:
		_fail("MISCLICK deck card %d" % chosen)
		return
	await _shot("deck_choose")
	await _press(sheet.call("confirm_button"))
	if bool(sheet.call("is_open")) or not bool(desk.call("used")):
		_fail("desk did not mark card %d" % chosen)
		return
	await _press(_button(screen, TranslationServer.translate("deck.open")))
	await _until(func() -> bool: return bool(sheet.call("is_open")))
	board.call("point_at", chosen)
	await _shot("deck_marked")
	await _press(sheet.call("back_button"))


## The deck stall's first card put in the deck in place of the first card it may replace.
func _exchange(screen: Node, sheet: Object) -> void:
	var controller: Object = _app.get("controller")
	var stall: Object = controller.call("deck_stall")
	await _afford(screen, int(stall.call("price", 0)))
	var goods: Object = screen.get("_deck_goods")
	var buy: Button = goods.call("card_button", 0)
	if buy == null or not buy.is_visible_in_tree() or buy.disabled:
		print("NO BUTTON deck stall")
		return
	var coming: CardInstance = stall.call("card", 0)
	await _shot("deck_stall")
	await _press(buy)
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_fail("deck stall did not open the deck sheet")
		return
	var board: Object = sheet.call("board")
	var chosen: int = -1
	for card_id: int in board.call("card_ids"):
		if not bool(board.call("is_plot", card_id)) and stall.call("refusal", 0, card_id) == "":
			chosen = card_id
			break
	var view: Control = board.call("view_of", chosen)
	await _mouse_click(view.get_global_transform_with_canvas() * CARD_SPOT)
	if int(board.get("picked")) != chosen:
		_fail("MISCLICK deck card %d" % chosen)
		return
	await _shot("deck_exchange_choose")
	await _press(sheet.call("confirm_button"))
	var state: RunState = controller.call("state_copy")
	var landed: bool = state.deck.rank_of(chosen) == coming.base_rank()
	if bool(sheet.call("is_open")) or not landed or state.deck.suit_of(chosen) != coming.suit():
		_fail("deck stall did not put its card in slot %d" % chosen)
		return
	exchanged = true
	await _press(_button(screen, TranslationServer.translate("deck.open")))
	await _until(func() -> bool: return bool(sheet.call("is_open")))
	board.call("point_at", chosen)
	await _shot("deck_exchanged")
	await _press(sheet.call("back_button"))


## The deck sheet over the table, opened by the Deck key and shut by Cancel.
func table_deck() -> void:
	var switcher: Object = _app.get("switcher")
	var table_screen: Node = switcher.call("current")
	var sheet: Object = table_screen.get("_deck")
	await _key_action("commons_deck")
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_fail("the Deck key did not open the deck sheet")
		return
	await _shot("deck_table")
	await _key_action("ui_cancel")
	if bool(sheet.call("is_open")):
		_fail("Cancel did not close the deck sheet")


## Tops the coupons up to price, in the record too, when the run is short of it.
func _afford(screen: Node, price: int) -> void:
	var controller: Object = _app.get("controller")
	var state: RunState = controller.call("state_copy")
	if state.coupons >= price:
		return
	var loop: RunLoop = controller.get("_loop")
	loop.state.coupons += price
	loop.record.checkpoint["coupons"] = int(loop.record.checkpoint["coupons"]) + price
	controller.call("reseal_book")
	screen.call("_refresh")
	await _frames(5)


## The player's first four cards in hand, each given one enhancement, photographed.
func table() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var cards: Array[CardInstance] = loop.player_cards()
	var kinds: Array[String] = CardInstance.ENHANCEMENTS
	for index: int in mini(kinds.size(), cards.size()):
		var marked: Callable = func(card: CardInstance) -> void:
			CardMarks.enhance(loop.state, card, kinds[index])
		loop.round_state().mark(RunLoop.PLAYER, cards[index].id(), marked)
	var switcher: Object = _app.get("switcher")
	var table_screen: Node = switcher.call("current")
	var hand: Object = _app.get("hand")
	hand.call("refresh")
	var hand_view: Object = table_screen.get("_hand_view")
	hand_view.call("show_cards")
	await _frames(5)
	var shown: int = 0
	var views: Array = hand_view.get("_views")
	for view: Control in views:
		if view.visible and kinds.has(str(view.call("shown_enhancement"))):
			shown += 1
	if shown < mini(kinds.size(), cards.size()):
		_fail("FAN MISMATCH marks shown %d" % shown)
	await _shot("marks_hand")


func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	print("NO BUTTON '%s'" % text)
	return null


func _press(button: Button) -> void:
	if button == null or not button.is_visible_in_tree():
		return
	await _mouse_click(button.get_global_transform_with_canvas() * (button.size / 2.0))
	await _frames(5)


## Presses and lets go of the first key the action has, as a player at the keyboard does.
func _key_action(action: String) -> void:
	var key: Key = KEY_NONE
	for event: InputEvent in InputMap.action_get_events(action):
		var bound: InputEventKey = event as InputEventKey
		if bound != null:
			key = bound.physical_keycode if bound.physical_keycode != KEY_NONE else bound.keycode
			break
	for pressed: bool in [true, false]:
		var press: InputEventKey = InputEventKey.new()
		press.physical_keycode = key
		press.keycode = key
		press.pressed = pressed
		_tree.root.push_input(press, true)
		await _frames(2)


func _mouse_click(at: Vector2) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	_tree.root.push_input(move, true)
	await _frames(1)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		_tree.root.push_input(click, true)
		await _frames(1)


func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	return true


func _fail(reason: String) -> void:
	print("MISS %s" % reason)
	misclicks += 1


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


func _shot(name: String) -> void:
	await _tree.create_timer(SETTLE_SECONDS).timeout
	_tree.call("audit_layout", name)
	shots += 1
	if _headless:
		print("FRAME %02d_%s" % [shots, name])
		return
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%02d_%s.png" % [shots, name])
	_tree.root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

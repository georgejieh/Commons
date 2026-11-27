extends WalkBase
## The playtest's frames of marks on deck cards (ADR 0041), with real clicks. In the state
## store the Deck button opens the deck sheet (deck_sheet) and Close shuts it; the desk's
## ticket opens it again to choose, a click picks the first card the desk would mark
## (deck_choose), the confirm marks it, and the Deck button shows the deck with the new
## mark (deck_marked). The deck stall's first card is bought (deck_stall), a click picks
## the first deck card it may replace (deck_exchange_choose), the confirm makes the
## exchange, and the Deck button shows the deck with the card in (deck_exchanged), ADR
## 0042. At the table the player's first four cards take Model, Sheaf, Pennant and Surplus
## through the run's own path for a mark, and the hand is photographed with all four
## (marks_hand); the marks stay for the rest of the walk. After the exchange the Deck key
## opens the sheet over the table (deck_table) and Cancel shuts it.
## Development only; tools/ never ships.

## Where on a fanned card a click lands, in its own pixels: on the strip the next card
## leaves showing.
const CARD_SPOT: Vector2 = Vector2(14.0, 84.0)
## Frames a press of the store's buttons is given to open or close what it opens.
const PRESS_FRAMES: int = 5

## True once the walk made an exchange at the state store.
var exchanged: bool = false


## The deck sheet read-only, then one use of the state store's desk, from the store.
func store() -> void:
	var screen: Node = _current()
	var sheet: Object = member(screen, "deck")
	await _press_and_wait(_button_in(screen, tr("deck.open")))
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_misclick("deck sheet did not open")
		return
	await _shot("deck_sheet")
	await _press_and_wait(sheet.call("back_button"))
	if bool(sheet.call("is_open")):
		_misclick("deck sheet did not close")
		return
	await _desk(screen, sheet)
	await _exchange(screen, sheet)


## The player's first four cards in hand, each given one enhancement, photographed.
func table() -> void:
	var loop: RunLoop = _loop()
	var cards: Array[CardInstance] = loop.player_cards()
	var kinds: Array[String] = CardInstance.ENHANCEMENTS
	for index: int in mini(kinds.size(), cards.size()):
		var marked: Callable = func(card: CardInstance) -> void:
			CardMarks.enhance(loop.state, card, kinds[index])
		loop.round_state().mark(RunLoop.PLAYER, cards[index].id(), marked)
	var hand: Object = app.get("hand")
	hand.call("refresh")
	var hand_view: Object = member(_current(), "hand_view")
	hand_view.call("show_cards")
	await _frames(5)
	var shown: int = 0
	var views: Array = member(hand_view, "_views")
	for card_view: Control in views:
		if card_view.visible and kinds.has(str(card_view.call("shown_enhancement"))):
			shown += 1
	if shown < mini(kinds.size(), cards.size()):
		_fail("FAN MISMATCH marks shown %d" % shown)
	await _shot("marks_hand")


## The deck sheet over the table, opened by the Deck key and shut by Cancel.
func table_deck() -> void:
	var sheet: Object = member(_current(), "deck")
	await _key_action(KeyBindings.DECK)
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_misclick("the Deck key did not open the deck sheet")
		return
	await _shot("deck_table")
	await _key_action("ui_cancel")
	if bool(sheet.call("is_open")):
		_misclick("Cancel did not close the deck sheet")


func _desk(screen: Node, sheet: Object) -> void:
	var desk: Object = view(_controller(), ScreenId.STORE).call("mark_desk", false)
	await _afford(screen, int(desk.call("price")))
	var stall: Object = member(screen, "desk_stall")
	var ticket: Button = stall.get("ticket")
	await _press_and_wait(ticket)
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_misclick("desk did not open the deck sheet")
		return
	var board: Object = sheet.call("board")
	var chosen: int = -1
	for card_id: int in board.call("card_ids"):
		if not bool(board.call("is_plot", card_id)) and desk.call("refusal", card_id) == "":
			chosen = card_id
			break
	if not await _pick(board, chosen):
		return
	await _shot("deck_choose")
	await _press_and_wait(sheet.call("confirm_button"))
	if bool(sheet.call("is_open")) or not bool(desk.call("used")):
		_misclick("desk did not mark card %d" % chosen)
		return
	await _show_deck(screen, sheet, board, chosen, "deck_marked")


## The deck stall's first card put in the deck in place of the first card it may replace.
func _exchange(screen: Node, sheet: Object) -> void:
	var controller: Object = _controller()
	var stall: Object = view(controller, "store").call("deck_stall")
	await _afford(screen, int(stall.call("price", 0)))
	var goods: Object = member(screen, "deck_goods")
	var buy: Button = goods.call("card_button", 0)
	var coming: CardInstance = stall.call("card", 0)
	await _shot("deck_stall")
	await _press_and_wait(buy)
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_misclick("deck stall did not open the deck sheet")
		return
	var board: Object = sheet.call("board")
	var chosen: int = -1
	for card_id: int in board.call("card_ids"):
		if not bool(board.call("is_plot", card_id)) and stall.call("refusal", 0, card_id) == "":
			chosen = card_id
			break
	if not await _pick(board, chosen):
		return
	await _shot("deck_exchange_choose")
	await _press_and_wait(sheet.call("confirm_button"))
	var state: RunState = controller.call("state_copy")
	var landed: bool = state.deck.rank_of(chosen) == coming.base_rank()
	if bool(sheet.call("is_open")) or not landed or state.deck.suit_of(chosen) != coming.suit():
		_misclick("deck stall did not put its card in slot %d" % chosen)
		return
	exchanged = true
	await _show_deck(screen, sheet, board, chosen, "deck_exchanged")


## Clicks the card chosen on the deck sheet's board; false, said, when it was not picked.
func _pick(board: Object, chosen: int) -> bool:
	var card_view: Control = board.call("view_of", chosen)
	await _mouse_click(card_view.get_global_transform_with_canvas() * CARD_SPOT)
	if int(board.get("picked")) != chosen:
		_misclick("deck card %d" % chosen)
		return false
	return true


## The deck sheet opened by the Deck button, pointing at card_id, photographed and shut.
func _show_deck(screen: Node, sheet: Object, board: Object, card_id: int, name: String) -> void:
	await _press_and_wait(_button_in(screen, tr("deck.open")))
	await _until(func() -> bool: return bool(sheet.call("is_open")))
	board.call("point_at", card_id)
	await _shot(name)
	await _press_and_wait(sheet.call("back_button"))


## Tops the coupons up to price, in the record too, when the run is short of it.
func _afford(screen: Node, price: int) -> void:
	var controller: Object = _controller()
	var state: RunState = controller.call("state_copy")
	if state.coupons >= price:
		return
	var loop: RunLoop = _loop()
	loop.state.coupons += price
	loop.record.checkpoint["coupons"] = int(loop.record.checkpoint["coupons"]) + price
	controller.call("reseal_book")
	invoke(screen, "refresh")
	await _frames(5)


func _press_and_wait(button: Button) -> void:
	await _press(button)
	await _frames(PRESS_FRAMES)


## Presses and lets go of the first key the action has, as a player at the keyboard does.
func _key_action(action: String) -> void:
	var key: Key = KEY_NONE
	for event: InputEvent in InputMap.action_get_events(action):
		var bound: InputEventKey = event as InputEventKey
		if bound != null:
			key = bound.physical_keycode if bound.physical_keycode != KEY_NONE else bound.keycode
			break
	await _press_key(key)

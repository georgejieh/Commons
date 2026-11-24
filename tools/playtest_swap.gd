extends RefCounted
## The playtest's walk through the private-plot swap (ADR 0038), with real clicks. At
## the Quota's start the plot is stocked, in the run's state and its checkpoint so a save
## replays it, with a Model card and a stamped one. The first swap is made by clicking a
## hand card and then a plot card, and sent with Swap; the second by dragging a plot card
## onto a hand card, then taken back with its Undo, and the hand kept; every later one
## keeps the hand. Each time the sheet opens the plot must hold the same cards as it was
## given, the cards swapped in last round back in it. A click that does not do what it
## should is a miss. Loaded at run time by playtest.gd, so it reaches every UI node as
## Object, Node or Control, never by a ui/ class name. Development only; tools/ never
## ships.

const SETTLE_SECONDS: float = 1.8
const SNAP_SECONDS: float = 0.22
const WAIT_SECONDS: float = 20.0
const AWAIT_SWAP: int = 2
## Where a card is clicked, from its top left: on the strip an overlapped card shows.
const CARD_SPOT: Vector2 = Vector2(22, 84)
const DRAG_STEPS: int = 4

var shots: int = 0
var misclicks: int = 0
## Swap sheets answered so far.
var answered: int = 0

var _tree: SceneTree
var _app: Node
var _out: String
var _headless: bool
var _plot_ids: Array[int] = []


func _init(tree: SceneTree, app: Node, out: String, headless: bool, shot_count: int) -> void:
	_tree = tree
	_app = app
	_out = out
	_headless = headless
	shots = shot_count


## Stocks the plot at the Quota's start, before any command, in the state and in the
## record's checkpoint, so the run's save replays it.
func grant(loop: RunLoop) -> void:
	var inventory: Dictionary = loop.record.checkpoint["inventory"]
	var saved: Array = inventory["plot"]
	for index: int in 2:
		var card: CardInstance = CardInstance.new(
			loop.state.take_plot_id(), Ranks.KING - index * 4, index, CardInstance.Origin.PLOT
		)
		if index == 0:
			CardMarks.make_model(loop.state, card)
		else:
			CardMarks.stamp(loop.state, card, RunLoop.PLAYER)
		loop.state.inventory.plot.append(card)
		saved.append(card.to_dict())
		_plot_ids.append(card.id())
	loop.record.checkpoint["next_plot_id"] = loop.state.next_plot_id


## Answers the swap the table waits on, with clicks, as the walk has reached it.
func answer(table: Node, round_number: int) -> void:
	misclicks = 0
	var sheet: Object = table.get("_swap_sheet")
	if not await _until(func() -> bool: return bool(sheet.call("is_open"))):
		_fail("NO SWAP SHEET")
		return
	_check_plot()
	var board: Control = sheet.call("board")
	var trade: Object = board.get("trade")
	if answered == 0:
		await _shot("round%d_swap" % round_number)
		await _trade_by_clicks(board, trade, round_number)
		await _press(sheet.call("swap_button"))
	elif answered == 1:
		await _trade_by_drag(board, trade, round_number)
		var undo: Array = sheet.call("undo_buttons")
		if undo.is_empty():
			_fail("NO UNDO")
		else:
			await _press(undo[0])
			_expect(int(trade.call("pairs")) == 0, "UNDO DID NOT TAKE THE PAIR BACK")
		await _press(sheet.call("keep_button"))
	else:
		await _press(sheet.call("keep_button"))
	answered += 1
	var controller: Object = _app.get("controller")
	if not await _until(func() -> bool: return int(controller.call("awaiting")) != AWAIT_SWAP):
		_fail("SWAP NOT ANSWERED")
	_expect(not bool(sheet.call("is_open")), "SWAP SHEET STILL OPEN")


func _trade_by_clicks(board: Control, trade: Object, round_number: int) -> void:
	var hand: Array = board.call("place_ids", 0)
	var plot: Array = board.call("place_ids", 2)
	var given: int = hand[0]
	var taken: int = plot[0]
	await _mouse_click(_spot(board, given))
	_expect(int(trade.get("picked")) == given, "HAND CARD NOT PICKED")
	await _snap("round%d_swap_picked" % round_number)
	await _mouse_click(_spot(board, taken))
	_expect(int(trade.call("pairs")) == 1, "PLOT CARD NOT TRADED")
	await _shot("round%d_swap_traded" % round_number)


func _trade_by_drag(board: Control, trade: Object, round_number: int) -> void:
	var hand: Array = board.call("place_ids", 0)
	var plot: Array = board.call("place_ids", 2)
	var from: Vector2 = _spot(board, plot[-1])
	var to: Vector2 = _spot(board, hand[2])
	await _mouse_move(from, 0)
	await _mouse_button(from, true)
	for step: int in range(1, DRAG_STEPS + 1):
		await _mouse_move(from.lerp(to, step / float(DRAG_STEPS)), MOUSE_BUTTON_MASK_LEFT)
	await _snap("round%d_swap_dragging" % round_number)
	await _mouse_button(to, false)
	_expect(int(trade.call("pairs")) == 1, "DRAG DID NOT TRADE")
	await _shot("round%d_swap_dragged" % round_number)


## The plot holds the cards it was given, whatever the rounds before did with them: a
## card swapped in last round is back in it.
func _check_plot() -> void:
	var controller: Object = _app.get("controller")
	var state: RunState = controller.call("state_copy")
	var held: Array[int] = []
	for card: CardInstance in state.inventory.plot:
		held.append(card.id())
	_expect(held == _plot_ids, "PLOT NOT RETURNED %s" % [held])


## Where to click a card on the board: its strip a neighbour leaves showing.
func _spot(board: Control, card_id: int) -> Vector2:
	var rect: Rect2 = board.call("card_rect", card_id)
	return board.get_global_transform_with_canvas() * (rect.position + CARD_SPOT)


func _mouse_click(at: Vector2) -> void:
	await _mouse_move(at, 0)
	await _mouse_button(at, true)
	await _mouse_button(at, false)


func _mouse_move(at: Vector2, mask: int) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	move.button_mask = mask
	_tree.root.push_input(move, true)
	await _frames(1)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.position = at
	if pressed:
		click.button_mask = MOUSE_BUTTON_MASK_LEFT
	_tree.root.push_input(click, true)
	await _frames(1)


func _press(button: Button) -> void:
	if button == null or not button.is_visible_in_tree() or button.disabled:
		_fail("NO BUTTON %s" % ("" if button == null else button.text))
		return
	await _mouse_click(button.get_global_transform_with_canvas() * (button.size / 2.0))


func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	return true


func _expect(held: bool, failure: String) -> void:
	if not held:
		_fail(failure)


func _fail(reason: String) -> void:
	print("MISCLICK swap: %s" % reason)
	misclicks += 1


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


func _snap(name: String) -> void:
	await _tree.create_timer(SNAP_SECONDS).timeout
	await _picture(name)


func _shot(name: String) -> void:
	await _tree.create_timer(SETTLE_SECONDS).timeout
	_tree.call("audit_layout", name)
	await _picture(name)


func _picture(name: String) -> void:
	shots += 1
	if _headless:
		print("FRAME %02d_%s" % [shots, name])
		return
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%02d_%s.png" % [shots, name])
	_tree.root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

extends WalkBase
## The playtest's walk through the private-plot swap (ADR 0038), with real clicks. At
## the Quota's start the plot is stocked, in the run's state and its checkpoint so a save
## replays it, with a Model card and a stamped one. The first swap is made by clicking a
## hand card and then a plot card, and sent with Swap; the second by dragging a plot card
## onto a hand card, then taken back with its Undo, and the hand kept; every later one
## keeps the hand. Each time the sheet opens the plot must hold the same cards as it was
## given, the cards swapped in last round back in it. A click that does not do what it
## should is a misclick. Development only; tools/ never ships.

const AWAIT_SWAP: int = 2
## Where a card is clicked, from its top left: on the strip an overlapped card shows.
const CARD_SPOT: Vector2 = Vector2(22, 84)
const DRAG_STEPS: int = 4

## Swap sheets answered so far.
var answered: int = 0

var _plot_ids: Array[int] = []


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
			CardMarks.enhance(loop.state, card, CardInstance.MODEL)
		else:
			CardMarks.stamp(loop.state, card, RunLoop.PLAYER)
		loop.state.inventory.plot.append(card)
		saved.append(card.to_dict())
		_plot_ids.append(card.id())
	loop.record.checkpoint["next_plot_id"] = loop.state.next_plot_id


## Answers the swap the table waits on, with clicks, as the walk has reached it.
func answer(table: Node, round_number: int) -> void:
	var sheet: Object = member(table, "_swap_sheet")
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
			_clicked(int(trade.call("pairs")) == 0, "undo did not take the pair back")
		await _press(sheet.call("keep_button"))
	else:
		await _press(sheet.call("keep_button"))
	answered += 1
	var controller: Object = _controller()
	if not await _until(func() -> bool: return int(controller.call("awaiting")) != AWAIT_SWAP):
		_misclick("swap not answered")
	if bool(sheet.call("is_open")):
		_misclick("swap sheet still open")


func _trade_by_clicks(board: Control, trade: Object, round_number: int) -> void:
	var hand: Array = board.call("place_ids", 0)
	var plot: Array = board.call("place_ids", 2)
	var given: int = hand[0]
	var taken: int = plot[0]
	await _mouse_click(_spot(board, given))
	_clicked(int(trade.get("picked")) == given, "hand card not picked")
	await _snap("round%d_swap_picked" % round_number)
	await _mouse_click(_spot(board, taken))
	_clicked(int(trade.call("pairs")) == 1, "plot card not traded")
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
	_clicked(int(trade.call("pairs")) == 1, "drag did not trade")
	await _shot("round%d_swap_dragged" % round_number)


## The plot holds the cards it was given, whatever the rounds before did with them: a
## card swapped in last round is back in it.
func _check_plot() -> void:
	var controller: Object = _controller()
	var state: RunState = controller.call("state_copy")
	var held: Array[int] = []
	for card: CardInstance in state.inventory.plot:
		held.append(card.id())
	_expect(held == _plot_ids, "PLOT NOT RETURNED %s" % [held])


## Where to click a card on the board: its strip a neighbour leaves showing.
func _spot(board: Control, card_id: int) -> Vector2:
	var rect: Rect2 = board.call("card_rect", card_id)
	return board.get_global_transform_with_canvas() * (rect.position + CARD_SPOT)


## A misclick on the swap sheet, unless held.
func _clicked(held: bool, failure: String) -> void:
	if not held:
		_misclick("swap: %s" % failure)

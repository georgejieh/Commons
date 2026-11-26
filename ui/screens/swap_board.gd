class_name SwapBoard
extends Control
## The plot swap's cards (ADR 0038), drawn as the table draws them, in three places side
## by side under their names. Your hand, in the table's rank order, as it will be played:
## a plot card traded in stands in it. The cards that sit the round out, one place for
## each swap the round allows. Your plot, in rank order, with a lent card's place left
## empty. A traded pair carries one number, on its plot card, its set-aside card and the
## place it left. A click picks a card and a click on the other side trades it; dragging
## one onto the other does the same, and a click on a traded card takes the pair back.
## Keyboard and gamepad move a cursor along every card and press the one under it.

signal changed
signal refused

enum Place { HAND, OUT, PLOT }

const CARD: Vector2 = SwapFit.CARD
## How far a picked card rises.
const LIFT: float = 28.0
## Room under a card for the cursor's bar, and how far a press must move to be a drag.
const CURSOR_ROOM: float = 18.0
const DRAG_START: float = 8.0
const MOVE_TIME: float = 0.16
var trade: PlotTrade
var _pool: CardPool
var _rank_map: PackedByteArray = PackedByteArray()
var _wild: Array[int] = []
var _hand: Array[CardInstance] = []
var _plot: Array[CardInstance] = []
var _plot_side: Dictionary[int, bool] = {}
var _views: Dictionary[int, CardView] = {}
var _labels: Array[Label] = []
var _out_places: Array[Control] = []
var _plot_places: Array[Control] = []
var _tags: Array[Label] = []
## Card IDs in cursor order, left to right, and where each card stands now.
var _order: Array[int] = []
var _spots: Dictionary[int, Vector2] = {}
var _cursor: int = 0
var _press_id: int = PlotTrade.NONE
var _press_at: Vector2 = Vector2.ZERO
var _grab: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drop_id: int = PlotTrade.NONE


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(_mark)
	focus_exited.connect(_mark)
	resized.connect(_lay_out.bind(false))


## Shows hand and plot for a fresh trade of up to limit pairs, with views from pool.
func show_cards(
	hand: Array[CardInstance],
	plot: Array[CardInstance],
	limit: int,
	pool: CardPool,
	hand_model: HandModel,
	wild: Array[int]
) -> void:
	clear()
	_pool = pool
	_rank_map = hand_model.rank_map()
	_wild = wild.duplicate()
	trade = PlotTrade.new(limit)
	_hand = _sorted(hand)
	_plot = _sorted(plot)
	_build_places(limit)
	for card: CardInstance in _hand + _plot:
		_plot_side[card.id()] = _plot.has(card)
		var view: CardView = pool.acquire()
		if view == null:
			continue
		if view.get_parent() != self:
			view.reparent(self, false)
		view.bind(card)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_wild(_wild.has(card.base_rank()))
		var folded: int = HandModel.fold(card.base_rank(), _rank_map)
		if folded >= 0:
			view.set_rank_note(tr("card.rank_as").format({"rank": tr(CardView.RANK_KEYS[folded])}))
		_views[card.id()] = view
	_cursor = 0
	_lay_out(false)


## Hands every view back to the pool and takes the places down.
func clear() -> void:
	for view: CardView in _views.values():
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		_pool.release(view)
	_views.clear()
	_plot_side.clear()
	_spots.clear()
	_order.clear()
	for piece: Control in _labels + _out_places + _plot_places + _tags:
		remove_child(piece)
		piece.queue_free()
	_labels.clear()
	_out_places.clear()
	_plot_places.clear()
	_tags.clear()
	_press_id = PlotTrade.NONE
	_dragging = false


## Presses a card as a click or a key does. Returns the trade's answer.
func press(card_id: int) -> PlotTrade.Reason:
	var side: int = PlotTrade.PLOT if _plot_side[card_id] else PlotTrade.HAND
	var reason: PlotTrade.Reason = trade.press(side, card_id)
	_after(reason)
	return reason


## Trades two cards as a drop does.
func drop(dragged: int, target: int) -> PlotTrade.Reason:
	var hand_id: int = target if _plot_side[dragged] else dragged
	var plot_id: int = dragged if _plot_side[dragged] else target
	var reason: PlotTrade.Reason = trade.pair(hand_id, plot_id)
	_after(reason)
	return reason


## Takes a pair back, as its Undo does.
func undo(index: int) -> void:
	trade.undo(index)
	_after(PlotTrade.Reason.OK)


func view_of(card_id: int) -> CardView:
	return _views.get(card_id)


func card_of(card_id: int) -> CardInstance:
	for card: CardInstance in _hand + _plot:
		if card.id() == card_id:
			return card
	return null


## Where a card stands in this board, for tests and the playtest.
func card_rect(card_id: int) -> Rect2:
	return Rect2(_spots.get(card_id, Vector2.ZERO), CARD)


## The cards of a place, left to right, as IDs.
func place_ids(place: Place) -> Array[int]:
	var lists: Array[Array] = _places()
	var ids: Array[int] = []
	for card: CardInstance in lists[place]:
		ids.append(card.id())
	return ids


## The pairs' number tags, for tests.
func tags() -> Array[Label]:
	return _tags.duplicate()


func cursor_card() -> int:
	return _order[_cursor] if _cursor < _order.size() else PlotTrade.NONE


func _after(reason: PlotTrade.Reason) -> void:
	if reason == PlotTrade.Reason.NO_SWAPS_LEFT:
		refused.emit()
	_lay_out(true)
	changed.emit()


func _sorted(cards: Array[CardInstance]) -> Array[CardInstance]:
	var sorted: Array[CardInstance] = cards.duplicate()
	sorted.sort_custom(_before)
	return sorted


## Lowest first, by where each card ranks now, as the table's hand sorts by rank.
func _before(a: CardInstance, b: CardInstance) -> bool:
	var a_value: int = _rank_map[a.base_rank()]
	var b_value: int = _rank_map[b.base_rank()]
	if a_value != b_value:
		return a_value < b_value
	if a.base_rank() != b.base_rank():
		return a.base_rank() < b.base_rank()
	return a.id() < b.id()


func _build_places(limit: int) -> void:
	for key: String in ["plot.hand", "plot.out", "plot.plot"]:
		var label: Label = ScreenKit.eyebrow(tr(key))
		add_child(label)
		_labels.append(label)
	for index: int in limit:
		_out_places.append(_place())
	for index: int in _plot.size():
		_plot_places.append(_place())
	for pair: int in limit:
		for _place_index: int in Place.size():
			var tag: Label = SwapFit.tag(pair + 1)
			add_child(tag)
			_tags.append(tag)


func _place() -> Control:
	var place: Control = SwapFit.empty_place()
	add_child(place)
	move_child(place, 0)
	return place


## The height the board needs at the text size in use.
func needed_height() -> float:
	return _top() + CARD.y + CURSOR_ROOM


## Where the cards stand when not lifted: under the names and room for a lift or a tag.
func _top() -> float:
	var name_height: float = 0.0 if _labels.is_empty() else _labels[0].get_combined_minimum_size().y
	var tag_height: float = 0.0 if _tags.is_empty() else _tags[0].get_combined_minimum_size().y
	return name_height + 6.0 + maxf(LIFT, tag_height + 6.0)


## The width the board needs at its least steps, for the sheet's own size.
func needed_width() -> float:
	return SwapFit.needed_width(_counts())


func _counts() -> Array[int]:
	return [maxi(1, _hand.size()), maxi(1, _out_places.size()), maxi(1, _plot.size())]


func _places() -> Array[Array]:
	return SwapFit.places(_hand, _plot, trade, _sorted)


func _lay_out(animate: bool) -> void:
	if trade == null or _labels.is_empty():
		return
	var widths: Array[float] = []
	for label: Label in _labels:
		widths.append(label.get_combined_minimum_size().x)
	var fit: Array[Vector2] = SwapFit.fit(size.x, _counts(), widths)
	var top: float = _top()
	var lists: Array[Array] = _places()
	_order.clear()
	for place: int in Place.size():
		_labels[place].position = Vector2(fit[place].x, 0.0)
		_labels[place].size = _labels[place].get_combined_minimum_size()
		for index: int in lists[place].size():
			var card: CardInstance = lists[place][index]
			_spots[card.id()] = Vector2(fit[place].x + index * fit[place].y, top)
			_order.append(card.id())
	for index: int in _out_places.size():
		_out_places[index].position = Vector2(fit[Place.OUT].x + index * fit[Place.OUT].y, top)
	for index: int in _plot.size():
		_plot_places[index].position = Vector2(fit[Place.PLOT].x + index * fit[Place.PLOT].y, top)
	_cursor = clampi(_cursor, 0, maxi(0, _order.size() - 1))
	for index: int in _order.size():
		var view: CardView = _views.get(_order[index])
		if view != null:
			move_child(view, -1)
	for tag: Label in _tags:
		move_child(tag, -1)
	_place_tags(top)
	_mark()
	for card_id: int in _views:
		if card_id != _press_id or not _dragging:
			_move(_views[card_id], _rest(card_id), animate)
	custom_minimum_size = Vector2(needed_width(), needed_height())


## Each pair's number over its plot card in the hand, its set-aside card and the empty
## place in the plot it left.
func _place_tags(top: float) -> void:
	for tag: Label in _tags:
		tag.visible = false
	for pair: int in trade.pairs():
		var plot_id: int = trade.plot_ids[pair]
		var spots: Array[Vector2] = [_spots[plot_id], _spots[trade.hand_ids[pair]]]
		for index: int in _plot.size():
			if _plot[index].id() == plot_id:
				spots.append(_plot_places[index].position)
		for index: int in spots.size():
			var tag: Label = _tags[pair * Place.size() + index]
			tag.size = tag.get_combined_minimum_size()
			tag.position = Vector2(spots[index].x + 4.0, top - tag.size.y - 4.0)
			tag.visible = true


## Where a card rests: lifted while picked or a drop's target.
func _rest(card_id: int) -> Vector2:
	var at: Vector2 = _spots.get(card_id, Vector2.ZERO)
	if card_id == trade.picked or card_id == _drop_id:
		at.y -= LIFT
	return at


func _move(view: CardView, to: Vector2, animate: bool) -> void:
	view.z_index = 0
	if not animate or UiMotion.reduced() or not is_inside_tree():
		view.position = to
		return
	var motion: Tween = view.tween()
	motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(view, "position", to, MOVE_TIME)


## Picked and drop target in the selection's red; the cursor's bar while focused.
func _mark() -> void:
	for index: int in _order.size():
		var card_id: int = _order[index]
		var view: CardView = _views.get(card_id)
		if view == null:
			continue
		var lifted: bool = card_id == trade.picked or card_id == _drop_id
		view.set_marked(lifted, false, has_focus() and index == _cursor)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_on_button(button)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_on_motion(motion)
		return
	if _on_key(event):
		accept_event()


func _on_button(button: InputEventMouseButton) -> void:
	if button.pressed:
		_press_id = _card_at(button.position, PlotTrade.NONE)
		_press_at = button.position
		if _press_id != PlotTrade.NONE:
			_grab = button.position - _views[_press_id].position
			_cursor = maxi(0, _order.find(_press_id))
		grab_focus()
		return
	var pressed: int = _press_id
	_press_id = PlotTrade.NONE
	if _dragging:
		_dragging = false
		var target: int = _drop_id
		_drop_id = PlotTrade.NONE
		if target != PlotTrade.NONE:
			drop(pressed, target)
		else:
			_lay_out(true)
	elif pressed != PlotTrade.NONE and _card_at(button.position, PlotTrade.NONE) == pressed:
		press(pressed)


func _on_motion(motion: InputEventMouseMotion) -> void:
	if _press_id == PlotTrade.NONE or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if not _dragging and motion.position.distance_to(_press_at) < DRAG_START:
		return
	_dragging = true
	var view: CardView = _views[_press_id]
	view.settle()
	view.z_index = 5
	view.position = motion.position - _grab
	var target: int = _card_at(motion.position, _press_id)
	if target != PlotTrade.NONE and _plot_side[target] == _plot_side[_press_id]:
		target = PlotTrade.NONE
	if target != _drop_id:
		_drop_id = target
		_lay_out(true)


func _on_key(event: InputEvent) -> bool:
	for action: String in KeyBindings.CURSOR_STEPS:
		if event.is_action_pressed(action, true):
			_step_cursor(-1 if action.ends_with("left") else 1)
			return true
	if event.is_action_pressed("ui_accept") or event.is_action_pressed(KeyBindings.SELECT):
		if cursor_card() != PlotTrade.NONE:
			press(cursor_card())
		return true
	return false


func _step_cursor(step: int) -> void:
	_cursor = clampi(_cursor + step, 0, maxi(0, _order.size() - 1))
	_mark()


## The card under point, the topmost first, leaving out skip.
func _card_at(point: Vector2, skip: int) -> int:
	for index: int in range(_order.size() - 1, -1, -1):
		var card_id: int = _order[index]
		if card_id != skip and Rect2(_rest(card_id), CARD).has_point(point):
			return card_id
	return PlotTrade.NONE

class_name DeckBoard
extends Control
## The deck sheet's cards (ADR 0041): every deck card as its real face, one group a rank in
## rank order, then the private plot's cards, laid out by DeckFit in the room given. A
## group's name gives its count where it is not a plain deck's (ADR 0042), and a rank the
## deck holds none of keeps its name over an empty place. Each card shows its marks, and a
## slip keeps off every name (SlipPlacer.KEEP_CLEAR). Pointer, keys and pad move one cursor
## over the cards: left and right along the order, up and down a row of groups; the card
## under it is named in the shared slip beside it. When picking, a press picks the card
## under the cursor and lifts it; a plot card cannot be picked.

signal cursor_moved(card_id: int)
signal picked_card(card_id: int)

const NONE: int = -1
const LIFT: float = 22.0
## The rank names above the groups, and the plot's.
const NAME_SIZE: int = 18

## True while a press picks a card, as the desks ask; false on the read-only sheet.
var picking: bool = false
var picked: int = NONE

var _pool: CardPool = null
var _views: Dictionary[int, CardView] = {}
var _cards: Dictionary[int, CardInstance] = {}
## Card IDs in cursor order, and the group each stands in.
var _order: Array[int] = []
var _group_of: Dictionary[int, int] = {}
var _groups: Array[Array] = []
var _names: Array[Label] = []
var _fit: DeckFit = null
var _cursor: int = 0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_entered.connect(_mark)
	focus_exited.connect(_mark)


## Makes the views once, from a pool of their own, so opening the sheet instances none.
func prepare() -> void:
	if _pool != null:
		return
	_pool = CardPool.new()
	_pool.fill(self)


## Shows the deck cards, grouped by rank, and the plot's, fitted to room.
func show_cards(deck: Array[CardInstance], plot: Array[CardInstance], room: Vector2) -> void:
	clear()
	prepare()
	_groups.clear()
	var plain: PackedByteArray = Deck.new().rank_counts()
	for rank: int in Ranks.COUNT:
		var group: Array[CardInstance] = []
		for card: CardInstance in deck:
			if card.base_rank() == rank:
				group.append(card)
		_groups.append(group)
		var name: String = tr(CardView.RANK_KEYS[rank])
		if group.size() != plain[rank]:
			name = tr("deck.rank_count").format({"rank": name, "count": group.size()})
		_names.append(_name(name))
	if not plot.is_empty():
		_groups.append(plot.duplicate())
		_names.append(_name(tr("deck.plot")))
	for index: int in _groups.size():
		for card: CardInstance in _groups[index]:
			var view: CardView = _pool.acquire()
			view.bind(card)
			view.mouse_filter = Control.MOUSE_FILTER_STOP
			view.hovered.connect(_on_hovered)
			view.pressed.connect(_on_pressed)
			_views[card.id()] = view
			_cards[card.id()] = card
			_order.append(card.id())
			_group_of[card.id()] = index
	lay_out(room)


## Puts every view back in the pool and takes the names down.
func clear() -> void:
	for view: CardView in _views.values():
		view.hovered.disconnect(_on_hovered)
		view.pressed.disconnect(_on_pressed)
		_pool.release(view)
	_views.clear()
	_cards.clear()
	_order.clear()
	_group_of.clear()
	for label: Label in _names:
		remove_child(label)
		label.queue_free()
	_names.clear()
	picked = NONE
	_cursor = 0


## Fits the groups to room again, as when the text size or the window changes.
func lay_out(room: Vector2) -> void:
	if _groups.is_empty():
		return
	var name_height: float = _names[0].get_combined_minimum_size().y + 4.0
	var counts: Array[int] = []
	for group: Array in _groups:
		counts.append(group.size())
	_fit = DeckFit.fit(counts, room, name_height)
	for index: int in _groups.size():
		var at: Vector2 = _fit.places[index]
		_names[index].position = at
		_names[index].size = _names[index].get_combined_minimum_size()
		var cards: Array = _groups[index]
		for place: int in cards.size():
			var card: CardInstance = cards[place]
			var view: CardView = _views[card.id()]
			# Scaled from its corner, so it stands in the place the fit gave it and its
			# foot stays above the next row's names.
			view.pivot_offset = Vector2.ZERO
			view.scale = Vector2.ONE * _fit.scale
			view.position = at + Vector2(place * _fit.steps[index], name_height)
			view.z_index = 0
			move_child(view, -1)
	custom_minimum_size = _fit.size + Vector2(0.0, LIFT)
	_mark()


## The scale the cards are drawn at now, for tests.
func card_scale() -> float:
	return _fit.scale if _fit != null else 1.0


func view_of(card_id: int) -> CardView:
	return _views.get(card_id)


func card_of(card_id: int) -> CardInstance:
	return _cards.get(card_id)


func card_ids() -> Array[int]:
	return _order.duplicate()


func cursor_card() -> int:
	return _order[_cursor] if _cursor < _order.size() else NONE


## True for a plot card, which the desks never mark.
func is_plot(card_id: int) -> bool:
	return _cards.has(card_id) and _cards[card_id].origin() == CardInstance.Origin.PLOT


## Moves the cursor to the card, as a hover or a key does.
func point_at(card_id: int) -> void:
	var at: int = _order.find(card_id)
	if at < 0:
		return
	_cursor = at
	_mark()
	cursor_moved.emit(card_id)


## Presses the card as a click or the accept key does.
func press(card_id: int) -> void:
	point_at(card_id)
	if not picking or is_plot(card_id):
		return
	picked = card_id
	_mark()
	picked_card.emit(card_id)


func _name(text: String) -> Label:
	var label: Label = ScreenKit.eyebrow(text)
	label.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_to_group(SlipPlacer.KEEP_CLEAR)
	add_child(label)
	return label


## The picked card lifts with the selection's red edge, the cursor's card has the bar.
func _mark() -> void:
	if _fit == null:
		return
	for index: int in _order.size():
		var card_id: int = _order[index]
		var view: CardView = _views[card_id]
		var lifted: bool = card_id == picked
		view.set_marked(lifted, false, has_focus() and index == _cursor)
		var rest_y: float = _rest_y(card_id)
		view.position.y = rest_y - (LIFT * _fit.scale if lifted else 0.0)
		view.z_index = ScreenKit.LAYER_LIFTED if lifted else 0


func _rest_y(card_id: int) -> float:
	var name_height: float = _names[0].get_combined_minimum_size().y + 4.0
	return _fit.places[_group_of[card_id]].y + name_height


func _on_hovered(card_id: int) -> void:
	point_at(card_id)


func _on_pressed(card_id: int) -> void:
	grab_focus()
	press(card_id)


func _gui_input(event: InputEvent) -> void:
	if _order.is_empty():
		return
	var step: int = KeyBindings.cursor_step(event)
	if step != 0:
		_step(step)
		accept_event()
		return
	for action: String in ["ui_up", "ui_down"]:
		if event.is_action_pressed(action, true) and _step_row(-1 if action == "ui_up" else 1):
			accept_event()
			return
	if KeyBindings.is_pick(event):
		press(cursor_card())
		accept_event()


func _step(by: int) -> void:
	point_at(_order[clampi(_cursor + by, 0, _order.size() - 1)])


## To the first card of the group a row above or below, or the last group of a shorter
## last row, or the nearest group of that row with a card in it, past a row of empty
## ones. False when there is no such row that way, so the focus may leave for the buttons.
func _step_row(by: int) -> bool:
	var columns: int = _fit.columns
	var at: int = _group_of[cursor_card()]
	var rows: int = ceili(_groups.size() / float(columns))
	var row: int = floori(at / float(columns)) + by
	while row >= 0 and row < rows:
		var aimed: int = mini(row * columns + at % columns, _groups.size() - 1)
		for group: int in _nearest_in_row(aimed, row):
			var cards: Array = _groups[group]
			if not cards.is_empty():
				var card: CardInstance = cards[0]
				point_at(card.id())
				return true
		row += by
	return false


## The groups of row, the aimed one first, then outward from it.
func _nearest_in_row(aimed: int, row: int) -> Array[int]:
	var first: int = row * _fit.columns
	var last: int = mini(first + _fit.columns, _groups.size()) - 1
	var order: Array[int] = [aimed]
	for reach: int in range(1, _fit.columns):
		for group: int in [aimed - reach, aimed + reach]:
			if group >= first and group <= last:
				order.append(group)
	return order

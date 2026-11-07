class_name HandView
extends Control
## The player's hand as a fan along the bottom of the table. Positions sit on an arc,
## computed in O(n). Click toggles a card; press and drag across cards selects or
## clears them all the way the first card went. Keyboard and gamepad move a cursor
## along the fan and toggle the card under it (P3B.11). Selection lives in the
## HandModel.

enum Sort { RANK, SUIT, GROUPS }

## Most space between card centers, and how far the arc and lift bend, in pixels.
const MAX_SPACING: float = 64.0
const ARC_DROP: float = 0.6
const TILT_PER_CARD: float = 0.025
const LIFT: float = 32.0
## How far below the fan a freshly dealt card starts.
const DEAL_RISE: float = 260.0
## Jokers have no suit, so suit sorting puts them after the four suits.
const SUIT_LAST: int = 4
## The string key naming each sort, for the Sort button.
const SORT_KEYS: Dictionary[Sort, String] = {
	Sort.RANK: "sort.rank", Sort.SUIT: "sort.suit", Sort.GROUPS: "sort.groups"
}

## Tweens the lift of a selected or hovered card, when set.
var motion: TableMotion = null
var sort_mode: Sort = Sort.RANK

var _hinted: Array[int] = []
var _model: HandModel
var _pool: CardPool
var _views: Array[CardView] = []
var _dragging: bool = false
var _drag_selects: bool = true
## The card the keyboard or gamepad points at, or -1 before either is used.
var _cursor: int = -1


func setup(model: HandModel, pool: CardPool) -> void:
	_model = model
	_pool = pool
	_model.changed.connect(_mark)


## Lays out the model's cards with pooled views, in the current sort order.
func show_cards() -> void:
	_hinted.clear()
	for view: CardView in _views:
		_disconnect(view)
		_pool.release(view)
	_views.clear()
	for card: CardInstance in _sorted(_model.cards()):
		var view: CardView = _pool.acquire()
		if view.get_parent() != self:
			view.reparent(self, false)
		view.bind(card)
		_note_fold(view, card)
		view.pressed.connect(_on_pressed)
		view.hovered.connect(_on_hovered)
		_views.append(view)
	if _cursor >= _views.size():
		_cursor = _views.size() - 1
	_layout()
	_mark()


## Moves the cursor by step cards, stopping at either end. The first move lands on
## the leftmost card.
func move_cursor(step: int) -> void:
	if _views.is_empty():
		return
	_cursor = 0 if _cursor < 0 else clampi(_cursor + step, 0, _views.size() - 1)
	_mark()


## Toggles the card under the cursor.
func toggle_cursor() -> void:
	if _cursor < 0 or _cursor >= _views.size():
		move_cursor(0)
		return
	_model.toggle(_views[_cursor].card_id)


## The card under the cursor, or -1.
func cursor_card() -> int:
	if _cursor < 0 or _cursor >= _views.size():
		return -1
	return _views[_cursor].card_id


## Where a card in the fan sits on screen, its middle, or the fan's middle when the
## card isn't shown.
func card_center(card_id: int) -> Vector2:
	for view: CardView in _views:
		if view.card_id == card_id:
			return view.get_global_transform() * (view.size / 2.0)
	return global_position + size / 2.0


## Lights these cards with the hint edge until the hand next changes.
func show_hint(ids: Array[int]) -> void:
	_hinted = ids.duplicate()
	_mark()


func set_sort(mode: Sort) -> void:
	sort_mode = mode
	show_cards()


## A fresh deal: every card rises into the fan from below, one after another.
func deal_in() -> void:
	if motion == null or motion.reduced:
		return
	for index: int in _views.size():
		var view: CardView = _views[index]
		var rest: Vector2 = view.position
		view.position = rest + Vector2(0, DEAL_RISE)
		view.modulate.a = 0.0
		var tween: Tween = view.tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var delay: float = index * TableMotion.PRESETS.deal_stagger
		var seconds: float = TableMotion.PRESETS.fly_time
		tween.tween_property(view, "position", rest, seconds).set_delay(delay)
		tween.tween_property(view, "modulate:a", 1.0, seconds * 0.6).set_delay(delay)


## Where card index sits for n cards: x, y and rotation. Pure, for tests.
static func fan_slot(index: int, count: int, width: float) -> Vector3:
	var spacing: float = minf(MAX_SPACING, width / maxf(1.0, count))
	var offset: float = index - (count - 1) / 2.0
	var x: float = width / 2.0 + offset * spacing
	var y: float = ARC_DROP * offset * offset
	return Vector3(x, y, offset * TILT_PER_CARD)


func _layout() -> void:
	for index: int in _views.size():
		var slot: Vector3 = fan_slot(index, _views.size(), size.x)
		var view: CardView = _views[index]
		view.position = Vector2(slot.x - view.size.x / 2.0, slot.y)
		view.rotation = slot.z
		# Clicks go to the last child under the cursor, so tree order must match the
		# fan: each card sits above the one to its left.
		move_child(view, index)


func _mark() -> void:
	var hinted: Array[int] = _hinted
	for index: int in _views.size():
		var view: CardView = _views[index]
		var selected: bool = _model.is_selected(view.card_id)
		view.set_marked(selected, hinted.has(view.card_id), index == _cursor)
		var slot: Vector3 = fan_slot(index, _views.size(), size.x)
		var to: Vector2 = Vector2(view.position.x, slot.y - (LIFT if selected else 0.0))
		if motion == null:
			view.position = to
		else:
			motion.move(view, to, slot.z, TableMotion.PRESETS.select)


func _sorted(cards: Array[CardInstance]) -> Array[CardInstance]:
	if sort_mode == Sort.GROUPS:
		return _model.grouped_cards()
	var sorted: Array[CardInstance] = cards.duplicate()
	sorted.sort_custom(_by_suit if sort_mode == Sort.SUIT else _before)
	return sorted


## Suit first, jokers last, then rank within each suit.
func _by_suit(a: CardInstance, b: CardInstance) -> bool:
	var a_suit: int = SUIT_LAST if a.base_rank() >= Ranks.SMALL_JOKER else a.suit()
	var b_suit: int = SUIT_LAST if b.base_rank() >= Ranks.SMALL_JOKER else b.suit()
	if a_suit != b_suit:
		return a_suit < b_suit
	return _before(a, b)


func _before(a: CardInstance, b: CardInstance) -> bool:
	if a.base_rank() != b.base_rank():
		return a.base_rank() < b.base_rank()
	return a.id() < b.id()


func _on_pressed(card_id: int) -> void:
	_dragging = true
	_drag_selects = not _model.is_selected(card_id)
	_model.set_selected(card_id, _drag_selects)


func _on_hovered(card_id: int) -> void:
	if _dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_model.set_selected(card_id, _drag_selects)


func _input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false


## Marks a card a debuff makes rank as another, such as "as 3" on a 2.
func _note_fold(view: CardView, card: CardInstance) -> void:
	var folded: int = _model.folded_rank(card)
	if folded >= 0:
		view.set_rank_note(tr("card.rank_as").format({"rank": tr(CardView.RANK_KEYS[folded])}))


func _disconnect(view: CardView) -> void:
	if view.pressed.is_connected(_on_pressed):
		view.pressed.disconnect(_on_pressed)
	if view.hovered.is_connected(_on_hovered):
		view.hovered.disconnect(_on_hovered)

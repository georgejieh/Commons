class_name HandView
extends Control
## The player's hand as a fan along the bottom of the table. Positions sit on an arc,
## computed in O(n). Click toggles a card; press and drag across cards selects or
## clears them all the way the first card went. Selection lives in the HandModel.

enum Sort { RANK, GROUPS }

## Most space between card centers, and how far the arc and lift bend, in pixels.
const MAX_SPACING: float = 64.0
const ARC_DROP: float = 0.6
const TILT_PER_CARD: float = 0.025
const LIFT: float = 32.0

## Tweens the lift of a selected or hovered card, when set.
var motion: TableMotion = null
var hint_on: bool = false
var sort_mode: Sort = Sort.RANK

var _model: HandModel
var _pool: CardPool
var _views: Array[CardView] = []
var _dragging: bool = false
var _drag_selects: bool = true


func setup(model: HandModel, pool: CardPool) -> void:
	_model = model
	_pool = pool
	_model.changed.connect(_mark)


## Lays out the model's cards with pooled views, in the current sort order.
func show_cards() -> void:
	for view: CardView in _views:
		_disconnect(view)
		_pool.release(view)
	_views.clear()
	for card: CardInstance in _sorted(_model.cards()):
		var view: CardView = _pool.acquire()
		if view.get_parent() != self:
			view.reparent(self, false)
		view.bind(card)
		view.pressed.connect(_on_pressed)
		view.hovered.connect(_on_hovered)
		_views.append(view)
	_layout()
	_mark()


func set_hint(on: bool) -> void:
	hint_on = on
	_mark()


func set_sort(mode: Sort) -> void:
	sort_mode = mode
	show_cards()


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
		view.z_index = index


func _mark() -> void:
	var hinted: Array[int] = []
	if hint_on:
		hinted = _model.hint_ids()
	for index: int in _views.size():
		var view: CardView = _views[index]
		var selected: bool = _model.is_selected(view.card_id)
		view.set_marked(selected, hinted.has(view.card_id))
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
	sorted.sort_custom(_before)
	return sorted


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


func _disconnect(view: CardView) -> void:
	if view.pressed.is_connected(_on_pressed):
		view.pressed.disconnect(_on_pressed)
	if view.hovered.is_connected(_on_hovered):
		view.hovered.disconnect(_on_hovered)

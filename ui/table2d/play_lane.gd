class_name PlayLane
extends Control
## The strip of table in front of one seat where that seat's current play lies. Cards
## are pooled views laid at fixed offsets, closing up so a long play still fits, and
## drop in one after another. It takes no clicks.

const PLAY_SCALE: float = 0.7
## Space between the left edges of cards in a lane; most of each card shows.
const LANE_SPACING: float = 56.0

var _pool: CardPool
var _pool_parent: Control
var _motion: TableMotion
var _views: Array[CardView] = []


func setup(pool: CardPool, pool_parent: Control, motion: TableMotion) -> void:
	_pool = pool
	_pool_parent = pool_parent
	_motion = motion
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_play(cards: Array[CardInstance]) -> void:
	clear()
	for card: CardInstance in cards:
		var view: CardView = _pool.acquire()
		if view == null:
			return
		view.reparent(self, false)
		view.bind(card)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.pivot_offset = Vector2.ZERO
		var order: int = _views.size()
		view.position = Vector2(order * _spacing(cards.size(), view), 0)
		_motion.drop(view, PLAY_SCALE, order)
		_views.append(view)


func clear() -> void:
	for view: CardView in _views:
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		view.reparent(_pool_parent, false)
		_pool.release(view)
	_views.clear()


func card_count() -> int:
	return _views.size()


func _spacing(count: int, view: CardView) -> float:
	if count < 2:
		return LANE_SPACING
	var room: float = size.x - view.size.x * PLAY_SCALE
	return minf(LANE_SPACING, room / (count - 1))

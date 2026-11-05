class_name PlayLane
extends Control
## The strip of table in front of one seat where that seat's current play lies. Cards
## are pooled views laid at fixed offsets, closing up so a long play still fits, and
## drop in one after another. A won trick sweeps them off toward the winner. It takes no
## clicks.

const PLAY_SCALE: float = 0.8
## Space between the left edges of cards in a lane; most of each card shows.
const LANE_SPACING: float = 62.0
## How much of the way to the winner a swept card travels before it fades out.
const SWEEP_REACH: float = 0.45

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


## Slides the play toward a point on screen, fading, then gives the views back. Under
## reduced motion it clears at once. The tweens belong to the views, so a reused or
## freed view takes its tween with it.
func sweep(toward: Vector2) -> void:
	if _views.is_empty():
		return
	if _motion.reduced:
		clear()
		return
	var seconds: float = _motion.duration(TableMotion.PRESETS.sweep)
	var last: Tween = null
	for view: CardView in _views:
		var target: Vector2 = view.position + (toward - view.global_position) * SWEEP_REACH
		last = view.tween().set_parallel(true)
		last.set_trans(TableMotion.PRESETS.sweep_transition as Tween.TransitionType)
		last.set_ease(TableMotion.PRESETS.sweep_ease as Tween.EaseType)
		last.tween_property(view, "position", target, seconds)
		last.tween_property(view, "modulate:a", 0.0, seconds)
	last.chain().tween_callback(clear)


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

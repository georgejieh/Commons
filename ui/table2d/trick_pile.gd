class_name TrickPile
extends Control
## The trick in the middle of the table. Each play flies in from whoever made it and
## lands on the pile a little askew but upright, its cards spread so every rank and suit
## shows. The newest play lies on top at full brightness and the plays under it dim, so
## the play to beat is plain. A won trick sweeps off toward the winner. Cards are pooled
## views; the pile takes no clicks.

## A play's last card has landed; count is how many cards it had.
signal landed(count: int)

const PLAY_SCALE: float = 0.8
## A card view's size at full scale.
const CARD: Vector2 = Vector2(120, 168)
## Space between the left edges of one play's cards: the rank and suit always show.
const CARD_SPACING: float = 50.0
## The farthest a play lands from the pile's middle, and the most it and each of its
## cards turn, in pixels and radians.
const SCATTER: Vector2 = Vector2(40, 16)
const PLAY_TILT: float = 0.07
const CARD_TILT: float = 0.02
## Brightness of the plays under the newest.
const BURIED: float = 0.6
## The size a card starts at as it leaves a seat, before it lands at PLAY_SCALE.
const LAUNCH_SCALE: float = 0.45
## How much of the way to the winner a swept card travels before it fades out.
const SWEEP_REACH: float = 0.55
## A thrown card starts turned by up to this much, in radians, and straightens as it
## lands; a counted card hops this far.
const THROW_SPIN: float = 0.7
const HOP: float = 14.0

var _pool: CardPool
var _pool_parent: Control
var _motion: TableMotion
var _views: Array[CardView] = []
## Where each play starts in _views, oldest first.
var _starts: Array[int] = []


func setup(pool: CardPool, pool_parent: Control, motion: TableMotion) -> void:
	_pool = pool
	_pool_parent = pool_parent
	_motion = motion
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lays a play on top of the pile. from is where it comes from on screen; origins, when
## given, is where each card starts, as when the player's cards leave the hand.
func show_play(cards: Array[CardInstance], from: Vector2, origins: Array[Vector2] = []) -> void:
	if cards.is_empty():
		return
	_bury()
	_starts.append(_views.size())
	var noise: int = hash([cards[0].id(), _starts.size()])
	var tilt: float = _unit(noise, 1) * PLAY_TILT
	var spacing: float = _spacing(cards.size())
	var card_size: Vector2 = CARD * PLAY_SCALE
	var span: float = spacing * (cards.size() - 1) + card_size.x
	var corner: Vector2 = (
		(size - Vector2(span, card_size.y)) / 2.0
		+ Vector2(_unit(noise, 2) * SCATTER.x, _unit(noise, 3) * SCATTER.y)
	)
	for order: int in cards.size():
		var view: CardView = _pool.acquire()
		if view == null:
			return
		view.reparent(self, false)
		view.bind(cards[order])
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.pivot_offset = Vector2.ZERO
		var along: float = order * spacing
		var rest: Vector2 = corner + Vector2(along, along * sin(tilt))
		var angle: float = tilt + _unit(noise, 10 + order) * CARD_TILT
		var start: Vector2 = origins[order] if order < origins.size() else from
		view.rotation = angle + _unit(noise, 30 + order) * THROW_SPIN
		var flight: Tween = _fly(view, start, rest, angle, order)
		_views.append(view)
		if order == cards.size() - 1:
			if flight == null:
				landed.emit(cards.size())
			else:
				flight.chain().tween_callback(landed.emit.bind(cards.size()))


## Slides the pile toward a point on screen, fading, then gives the views back. Under
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
		last.tween_property(view, "scale", Vector2.ONE * LAUNCH_SCALE, seconds)
		last.tween_property(view, "modulate:a", 0.0, seconds)
	last.chain().tween_callback(clear)


func clear() -> void:
	for view: CardView in _views:
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		view.reparent(_pool_parent, false)
		_pool.release(view)
	_views.clear()
	_starts.clear()


func card_count() -> int:
	return _views.size()


func play_count() -> int:
	return _starts.size()


## The cards of the play on top, the one to beat.
func top_ids() -> Array[int]:
	var ids: Array[int] = []
	if _starts.is_empty():
		return ids
	for index: int in range(_starts[-1], _views.size()):
		ids.append(_views[index].card_id)
	return ids


## The views of the play on top, for tests.
func top_views() -> Array[CardView]:
	var views: Array[CardView] = []
	if not _starts.is_empty():
		views.assign(_views.slice(_starts[-1]))
	return views


## Moves a card from start, a point on screen, to rest on the pile, growing from launch
## size, a beat after the card before it. Under reduced motion it lands at once.
func _fly(view: CardView, start: Vector2, rest: Vector2, angle: float, order: int) -> Tween:
	if _motion.reduced:
		view.position = rest
		view.rotation = angle
		view.scale = Vector2.ONE * PLAY_SCALE
		return null
	var launch: Vector2 = start - global_position - view.size * LAUNCH_SCALE / 2.0
	view.position = launch
	view.scale = Vector2.ONE * LAUNCH_SCALE
	var tween: Tween = view.tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var seconds: float = _motion.duration(TableMotion.PRESETS.fly_time)
	var delay: float = order * TableMotion.PRESETS.deal_stagger * 0.5
	tween.tween_property(view, "position", rest, seconds).set_delay(delay)
	tween.tween_property(view, "rotation", angle, seconds).set_delay(delay)
	tween.tween_property(view, "scale", Vector2.ONE * PLAY_SCALE, seconds).set_delay(delay)
	return tween


## Hops each card of the top play in turn, over seconds in all, as its Grain is counted.
func pulse_top(seconds: float) -> void:
	var top: Array[CardView] = top_views()
	if _motion.reduced or top.is_empty() or seconds <= 0.0:
		return
	var each: float = seconds / top.size()
	for order: int in top.size():
		var view: CardView = top[order]
		var rest: float = view.position.y
		var hop: Tween = view.tween()
		hop.tween_interval(order * each)
		hop.tween_property(view, "position:y", rest - HOP, each * 0.4)
		hop.tween_property(view, "position:y", rest, each * 0.6)


## Dims every play already on the pile.
func _bury() -> void:
	for view: CardView in _views:
		view.modulate = Color(BURIED, BURIED, BURIED, view.modulate.a)


## Closes a long play up so it still fits the pile's width.
func _spacing(count: int) -> float:
	if count < 2:
		return CARD_SPACING
	var room: float = size.x - CARD.x * PLAY_SCALE
	return minf(CARD_SPACING, room / (count - 1))


## A repeatable value in -1 to 1 from noise and a salt, so the same play always lands
## the same way, with no global random.
static func _unit(noise: int, salt: int) -> float:
	return float(hash(noise + salt * 7919) & 0xffff) / 32767.5 - 1.0

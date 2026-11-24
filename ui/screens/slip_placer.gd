class_name SlipPlacer
extends RefCounted
## Where a slip stands (commons-screens states.md): right beside the thing it explains,
## touching it or within REACH of it, on the side with room: the side asked for first,
## then the other of above and below, then right, then left. It is always wholly on the
## screen, never on the thing itself, which holds its own button, and it slides along a
## side, never past the thing's end, to keep off another button when a spot as close
## does so. Other papers and text it may cover: a slip is gone as soon as the pointer
## leaves, so it stays where the eye already is rather than jumping to a far edge.

## The sides a slip may stand on, in the order tried when the first one asked for fails.
const ABOVE: int = 0
const BELOW: int = 1
const RIGHT: int = 2
const LEFT: int = 3

## The farthest a slip ever stands from the thing it explains.
const REACH: float = 24.0
## Between the spots tried along a side.
const STEP: float = 24.0
## How much of a slip stays level with the thing when it slides along a side.
const OVERLAP: float = 48.0
## A pixel of the slip on the thing costs more than anything else can; a pixel past REACH
## next; a pixel on another button next; then each place down the order of sides; then a
## pixel slid along a side.
const ON_THING: float = 1.0e9
const TOO_FAR: float = 1.0e7
const ON_BUTTON: float = 1.0e3
const SIDE_STEP: float = 1.0e5
## Kept clear around a button, so a slip's edge never lies on one.
const BUTTON_CLEAR: float = 4.0


## The top-left corner for a slip of size beside keep, gap away from it on side first
## where that works. Buttons visible under root, but for own and what it holds, are kept
## off when a spot as close allows.
static func place(
	size: Vector2, keep: Rect2, gap: float, screen: Rect2, root: Node, own: Node, first: int = ABOVE
) -> Vector2:
	var buttons: Array[Rect2] = []
	if root != null:
		gather(root, own, buttons)
	var best: Vector2 = inside(keep.position, size, screen)
	var best_score: float = INF
	var rank: int = 0
	for side: int in _order(first):
		for spot: Vector2 in _along(side, size, keep, gap):
			var at: Vector2 = inside(spot, size, screen)
			var score: float = _cost(Rect2(at, size), keep, buttons, rank, spot.distance_to(at))
			score += (spot - _aligned(side, size, keep, gap)).length()
			if score < best_score:
				best_score = score
				best = at
		rank += 1
	return best


## Spot moved the least to put size inside screen, its top-left kept on when too big.
static func inside(spot: Vector2, size: Vector2, screen: Rect2) -> Vector2:
	return Vector2(
		clampf(spot.x, screen.position.x, maxf(screen.position.x, screen.end.x - size.x)),
		clampf(spot.y, screen.position.y, maxf(screen.position.y, screen.end.y - size.y))
	)


## The gap between two rectangles: 0 when they touch or overlap.
static func distance(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()


## Every button visible under root into buttons, as rectangles on the screen grown by
## BUTTON_CLEAR, leaving out own and what it holds.
static func gather(root: Node, own: Node, buttons: Array[Rect2]) -> void:
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var control: Control = node as Control
		if control == own or (own != null and own.is_ancestor_of(control)):
			continue
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = on_screen(control)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			buttons.append(rect.grow(BUTTON_CLEAR))


## A control's rectangle in the screen's own pixels, through any canvas layer.
static func on_screen(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform_with_canvas()
	return Rect2(xform.origin, control.size * xform.get_scale())


## What a slip at rect costs: on the thing, past reach, on buttons, its place in the
## order of sides, and how far the screen's edge pushed it.
static func _cost(
	rect: Rect2, keep: Rect2, buttons: Array[Rect2], rank: int, pushed: float
) -> float:
	var score: float = ON_THING * rect.intersection(keep).get_area()
	score += TOO_FAR * maxf(0.0, distance(rect, keep) - REACH)
	for box: Rect2 in buttons:
		score += ON_BUTTON * rect.intersection(box).get_area()
	return score + SIDE_STEP * rank + pushed


static func _order(first: int) -> Array[int]:
	var order: Array[int] = [first]
	for side: int in [ABOVE, BELOW, RIGHT, LEFT]:
		if not order.has(side):
			order.append(side)
	return order


## Where a slip on side stands before it slides: level with the thing's left or top.
static func _aligned(side: int, size: Vector2, keep: Rect2, gap: float) -> Vector2:
	match side:
		ABOVE:
			return Vector2(keep.position.x, keep.position.y - gap - size.y)
		BELOW:
			return Vector2(keep.position.x, keep.end.y + gap)
		RIGHT:
			return Vector2(keep.end.x + gap, keep.position.y)
	return Vector2(keep.position.x - gap - size.x, keep.position.y)


## The spots along side: level first, then slid either way in STEPs while at least
## OVERLAP of the slip, or all of the thing, stays level with it.
static func _along(side: int, size: Vector2, keep: Rect2, gap: float) -> Array[Vector2]:
	var start: Vector2 = _aligned(side, size, keep, gap)
	var across: bool = side == ABOVE or side == BELOW
	var axis: Vector2 = Vector2.RIGHT if across else Vector2.DOWN
	var low: float = keep.position.x if across else keep.position.y
	var length: float = size.x if across else size.y
	var span: float = keep.size.x if across else keep.size.y
	var least: float = low - length + minf(OVERLAP, minf(length, span))
	var most: float = low + span - minf(OVERLAP, minf(length, span))
	var spots: Array[Vector2] = [start]
	var step: float = STEP
	while low - step >= least or low + step <= most:
		if low - step >= least:
			spots.append(start - axis * step)
		if low + step <= most:
			spots.append(start + axis * step)
		step += STEP
	spots.append(start + axis * (least - low))
	spots.append(start + axis * (most - low))
	return spots

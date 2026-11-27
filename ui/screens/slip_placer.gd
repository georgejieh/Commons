class_name SlipPlacer
extends RefCounted
## Where a slip stands (commons-screens states.md): right beside the thing it explains,
## touching it or within REACH of it, on the side with room: the side asked for first,
## then the other of above and below, then right, then left. It is always wholly on the
## screen, never on the thing itself, which holds its own button, and it slides along a
## side, never past the thing's end, to keep off another button when a spot as close
## does so. Other papers and text it may cover, but for a control in the KEEP_CLEAR
## group, such as the deck sheet's rank names, which it keeps off on any side within
## reach before it keeps off a button: a slip is gone as soon as the pointer leaves, so it
## stays where the eye already is rather than jumping to a far edge.

## The sides a slip may stand on, in the order tried when the first one asked for fails.
enum Beside { ABOVE, BELOW, RIGHT, LEFT }

## The farthest a slip ever stands from the thing it explains.
const REACH: float = 24.0
## Between the spots tried along a side.
const STEP: float = 24.0
## How much of a slip stays level with the thing when it slides along a side.
const OVERLAP: float = 48.0
## The cost of each pixel of area the slip lies on the thing it explains, dearer than any other.
const ON_THING: float = 1.0e9
## The cost of each pixel the slip stands past REACH from the thing.
const TOO_FAR: float = 1.0e7
## A pixel on a control kept clear costs more than taking another side.
const ON_KEPT: float = 1.0e6
## The cost of each pixel of area the slip covers on another button.
const ON_BUTTON: float = 1.0e3
## The cost of each place down the order of sides; a pixel slid along a side costs one.
const SIDE_STEP: float = 1.0e5
## Kept clear around a button, so a slip's edge never lies on one.
const BUTTON_CLEAR: float = 4.0
## The group of controls a slip keeps off as it keeps off buttons.
const KEEP_CLEAR: StringName = &"slip_keep_clear"


## The top-left corner for a slip of size beside keep, gap away from it on side first
## where that works. Buttons visible under root, but for own and what it holds, are kept
## off when a spot as close allows.
static func place(
	size: Vector2,
	keep: Rect2,
	gap: float,
	screen: Rect2,
	root: Node,
	own: Node,
	first: Beside = Beside.ABOVE
) -> Vector2:
	var buttons: Array[Rect2] = []
	var kept: Array[Rect2] = []
	if root != null:
		_gather(root, own, buttons)
		_gather_kept(root, kept)
	var best: Vector2 = inside(keep.position, size, screen)
	var best_score: float = INF
	var rank: int = 0
	for side: Beside in _order(first):
		for spot: Vector2 in _along(side, size, keep, gap):
			var at: Vector2 = inside(spot, size, screen)
			var rect: Rect2 = Rect2(at, size)
			var score: float = _cost(rect, keep, buttons, rank, spot.distance_to(at))
			for box: Rect2 in kept:
				score += ON_KEPT * rect.intersection(box).get_area()
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
static func _gather(root: Node, own: Node, buttons: Array[Rect2]) -> void:
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var control: Control = node as Control
		if control == own or (own != null and own.is_ancestor_of(control)):
			continue
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = on_screen(control)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			buttons.append(rect.grow(BUTTON_CLEAR))


## Every control kept clear visible under root into kept, as much of its rectangle on the
## screen as no clipping parent hides, as a scrolled sheet hides what is scrolled away.
static func _gather_kept(root: Node, kept: Array[Rect2]) -> void:
	if not root.is_inside_tree():
		return
	for node: Node in root.get_tree().get_nodes_in_group(KEEP_CLEAR):
		var control: Control = node as Control
		if root.is_ancestor_of(control) and control.is_visible_in_tree():
			var shown: Rect2 = shown_rect(control)
			if shown.has_area():
				kept.append(shown)


## A control's rectangle on the screen, cut to what its clipping parents let show.
static func shown_rect(control: Control) -> Rect2:
	var rect: Rect2 = on_screen(control)
	var parent: Control = control.get_parent_control()
	while parent != null:
		if parent.clip_contents:
			rect = rect.intersection(on_screen(parent))
		parent = parent.get_parent_control()
	return rect


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


static func _order(first: Beside) -> Array[Beside]:
	var order: Array[Beside] = [first]
	for side: Beside in [Beside.ABOVE, Beside.BELOW, Beside.RIGHT, Beside.LEFT]:
		if not order.has(side):
			order.append(side)
	return order


## Where a slip on side stands before it slides: level with the thing's left or top.
static func _aligned(side: Beside, size: Vector2, keep: Rect2, gap: float) -> Vector2:
	match side:
		Beside.ABOVE:
			return Vector2(keep.position.x, keep.position.y - gap - size.y)
		Beside.BELOW:
			return Vector2(keep.position.x, keep.end.y + gap)
		Beside.RIGHT:
			return Vector2(keep.end.x + gap, keep.position.y)
	return Vector2(keep.position.x - gap - size.x, keep.position.y)


## The spots along side: level first, then slid either way in STEPs while at least
## OVERLAP of the slip, or all of the thing, stays level with it.
static func _along(side: Beside, size: Vector2, keep: Rect2, gap: float) -> Array[Vector2]:
	var start: Vector2 = _aligned(side, size, keep, gap)
	var across: bool = side == Beside.ABOVE or side == Beside.BELOW
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

class_name SlipPlacer
extends RefCounted
## Where a slip stands (commons-screens states.md): never on the thing it explains nor on
## any button, enabled or not, always inside the screen, and on as little of the page's
## text as it can while staying near the spot it would take on an empty page. Spots are
## tried beside the thing explained and across the screen on a grid; the one that covers
## no button and the least text, nearest the wanted spot, wins.

## Between the spots tried across the screen.
const STEP: float = 32.0
## Covering any of a button costs more than anything else can.
const HARD: float = 1.0e6
## A pixel away from the wanted spot costs this many pixels of covered text, and each
## piece of text touched costs as much as this many pixels of it.
const NEAR: float = 12.0
const TOUCH: float = 3000.0
## Kept clear around a button, so a slip's edge never lies on one.
const BUTTON_CLEAR: float = 4.0


## The top-left corner for a slip of size inside screen: wanted when it is clear, else the
## best spot. keep is the thing explained, which the slip stays gap away from; own is the
## slip itself, whose text is not avoided. Everything visible in root's tree is weighed.
static func place(
	size: Vector2, wanted: Vector2, keep: Rect2, gap: float, screen: Rect2, root: Node, own: Node
) -> Vector2:
	var hard: Array[Rect2] = [keep.grow(gap * 0.5)]
	var soft: Array[Rect2] = []
	gather(root, own, hard, soft)
	var spots: Array[Vector2] = [wanted]
	var sides: Array[float] = [
		keep.end.y + gap,
		keep.position.y - gap - size.y,
		keep.end.x + gap,
		keep.position.x - gap - size.x
	]
	var across: float = screen.position.x
	while across <= screen.end.x:
		spots.append(Vector2(across, sides[0]))
		spots.append(Vector2(across, sides[1]))
		across += STEP
	var down: float = screen.position.y
	while down <= screen.end.y:
		spots.append(Vector2(sides[2], down))
		spots.append(Vector2(sides[3], down))
		across = screen.position.x
		while across <= screen.end.x:
			spots.append(Vector2(across, down))
			across += STEP
		down += STEP
	var best: Vector2 = inside(wanted, size, screen)
	var best_score: float = INF
	for spot: Vector2 in spots:
		var at: Vector2 = inside(spot, size, screen)
		var score: float = NEAR * at.distance_to(wanted)
		if score >= best_score:
			continue
		score = _cost(Rect2(at, size), hard, soft, score, best_score)
		if score < best_score:
			best_score = score
			best = at
	return best


## Spot moved the least to put size inside screen, its top-left kept on when too big.
static func inside(spot: Vector2, size: Vector2, screen: Rect2) -> Vector2:
	return Vector2(
		clampf(spot.x, screen.position.x, maxf(screen.position.x, screen.end.x - size.x)),
		clampf(spot.y, screen.position.y, maxf(screen.position.y, screen.end.y - size.y))
	)


## Every button visible under root into hard and every piece of text into soft, as
## rectangles on the screen, leaving out own and what it holds.
static func gather(root: Node, own: Node, hard: Array[Rect2], soft: Array[Rect2]) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control == own or (own != null and own.is_ancestor_of(control)):
			continue
		var is_button: bool = control is BaseButton
		var is_text: bool = (
			(control is Label and not (control as Label).text.is_empty())
			or (control is RichTextLabel and not (control as RichTextLabel).text.is_empty())
		)
		if not (is_button or is_text) or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = on_screen(control)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if is_button:
			hard.append(rect.grow(BUTTON_CLEAR))
		else:
			soft.append(rect)


## A control's rectangle in the screen's own pixels, through any canvas layer.
static func on_screen(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform_with_canvas()
	return Rect2(xform.origin, control.size * xform.get_scale())


## What a slip at rect costs on top of score, stopping once it passes limit.
static func _cost(
	rect: Rect2, hard: Array[Rect2], soft: Array[Rect2], score: float, limit: float
) -> float:
	for box: Rect2 in hard:
		score += HARD * rect.intersection(box).get_area()
		if score >= limit:
			return score
	for box: Rect2 in soft:
		var covered: float = rect.intersection(box).get_area()
		if covered > 0.0:
			score += covered + TOUCH
			if score >= limit:
				return score
	return score

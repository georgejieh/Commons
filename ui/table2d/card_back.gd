class_name CardBack
extends Control
## A face-down card in flight between two villagers, so the player never sees a card they
## have no right to see (Redistribution, ADR 0023). Old paper, a border and a printed
## lattice in the chosen design's inks (ADR 0025), worn like everything else from
## corruption stage 0 (BowlGrime.wear()). Settings draws its swatches with it too. Its
## eye (BackEyes) is printed over the lattice only while the table's dread shows one.

const SIZE: Vector2 = Vector2(68, 96)
const BORDER: float = 6.0
const LATTICE: float = 12.0
const LATTICE_ALPHA: float = 0.35

## The design whose inks it is drawn in; the first design when none is set.
var design: CardBackDef = null:
	set(value):
		design = value
		queue_redraw()


func _init(extent: Vector2 = SIZE) -> void:
	size = extent
	custom_minimum_size = extent
	pivot_offset = extent / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(BackEyes.new())


func _draw() -> void:
	var inks: CardBackDef = design if design != null else CardBacks.POOL.backs[0]
	var worn: float = BowlGrime.wear()
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, BowlGrime.aged(inks.paper, worn))
	var border: Color = BowlGrime.faded(inks.border, worn)
	draw_rect(rect.grow(-BORDER * 0.5), border, false, BORDER)
	var line: Color = Color(BowlGrime.faded(inks.lattice, worn), LATTICE_ALPHA)
	var inner: Rect2 = rect.grow(-BORDER * 2.0)
	var x: float = inner.position.x
	while x < inner.end.x:
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), line, 1.0)
		x += LATTICE
	var y: float = inner.position.y
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), line, 1.0)
		y += LATTICE
	draw_rect(rect, Color(BowlGrime.TEA, 0.08 + 0.14 * worn))

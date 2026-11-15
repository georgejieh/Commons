class_name CardBack
extends Control
## A face-down card in flight between two villagers, so the player never sees a card they
## have no right to see (Redistribution, ADR 0023). Old paper, a red border and a printed
## lattice, worn like everything else from corruption stage 0 (BowlGrime.wear()).

const SIZE: Vector2 = Vector2(68, 96)
const BORDER: float = 6.0
const LATTICE: float = 12.0


func _init() -> void:
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(rect, CampaignPaper.paper(worn))
	var red: Color = CampaignPaper.ink(ScreenKit.RED, worn)
	draw_rect(rect.grow(-BORDER * 0.5), red, false, BORDER)
	var inner: Rect2 = rect.grow(-BORDER * 2.0)
	var x: float = inner.position.x
	while x < inner.end.x:
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(red, 0.35), 1.0)
		x += LATTICE
	var y: float = inner.position.y
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(red, 0.35), 1.0)
		y += LATTICE
	draw_rect(rect, Color(BowlGrime.TEA, 0.08 + 0.14 * worn))

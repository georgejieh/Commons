class_name ConfiscatedMark
extends Control
## Confiscation on the notice board (ADR 0023): a Cadre's card left out of the round is
## darkened, struck through in thin red strokes and stamped CONFISCATED across its middle
## in seal ink, at a tilt, so it reads at a glance at the board's small card size while
## its art and any name on it stay legible. The ink is worn from corruption stage 0 and
## fades further with BowlGrime.wear(). Drawn, not a label, so the board's only words
## stay in its tooltips and on its badges.

## How dark the card is shaded, from 0 to 1.
const SHADE: float = 0.38
## The width of the red strikes across the card, in pixels.
const STROKE: float = 3.0
## A stamp is art (ADR 0034): it keeps its size at every text size, and shrinks on a
## small card no further than the least size anything the player reads is set at.
const STAMP_SIZE: int = 17
## The smallest the stamp's type shrinks to on a small card.
const LEAST_SIZE: int = 14
## The share of the card's diagonal the stamp may span.
const FIT: float = 0.8
## The stamp's tilt, in radians.
const STAMP_TILT: float = -0.36
## Room kept between the stamp's word and its band's edges, in pixels.
const BAND_PAD: Vector2 = Vector2(7.0, 4.0)
## The width of the rule drawn inside the stamp's band, in pixels.
const RULE: float = 2.0
## How far in from the card's corners the red strikes start, in pixels.
const INSET: float = 8.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Shows the mark; animate presses it on like ink.
func strike(animate: bool) -> void:
	visible = true
	queue_redraw()
	if animate:
		UiMotion.stamp(self)


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	var ink: Color = CampaignPaper.ink(ScreenKit.RED, worn)
	draw_rect(Rect2(Vector2.ZERO, size), Color(ScreenKit.INK, SHADE))
	var corner: Vector2 = Vector2.ONE * INSET
	draw_line(corner, size - corner, Color(ink, 0.8), STROKE)
	draw_line(
		Vector2(size.x - INSET, INSET), Vector2(INSET, size.y - INSET), Color(ink, 0.8), STROKE
	)
	var word: String = tr("table.confiscated").to_upper()
	var font: Font = ScreenKit.DISPLAY_BOLD
	# Smaller type on a smaller card, so the stamp never runs off it.
	var type_size: int = STAMP_SIZE
	var wide: Vector2 = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size)
	while (
		type_size > TextSize.least(LEAST_SIZE) and wide.x + BAND_PAD.x * 2.0 > size.length() * FIT
	):
		type_size -= 1
		wide = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size)
	draw_set_transform(size / 2.0, STAMP_TILT)
	var band: Rect2 = Rect2(-wide / 2.0, wide).grow_individual(
		BAND_PAD.x, BAND_PAD.y, BAND_PAD.x, BAND_PAD.y
	)
	draw_rect(band, ink)
	draw_rect(band.grow(-RULE * 1.5), Color(ScreenKit.PAPER, 0.85), false, RULE)
	var baseline: Vector2 = Vector2(-wide.x / 2.0, font.get_ascent(type_size) - wide.y / 2.0)
	draw_string(font, baseline, word, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size, ScreenKit.PAPER)
	draw_set_transform(Vector2.ZERO, 0.0)

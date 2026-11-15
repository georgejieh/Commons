class_name ConfiscatedMark
extends Control
## Confiscation on the notice board (ADR 0023): a Cadre's card left out of the round is
## struck through in red ink and stamped, its art still in view under the strokes. The
## ink is worn from corruption stage 0 and fades further with BowlGrime.wear(). Drawn, not
## a label, so the board's only words stay in its tooltips.

const STROKE: float = 7.0
const STAMP_SIZE: int = 15
const STAMP_TILT: float = -0.32
const BAND_PAD: float = 4.0


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
	var ink: Color = CampaignPaper.ink(ScreenKit.RED, BowlGrime.wear())
	draw_line(Vector2(6, 6), size - Vector2(6, 6), Color(ink, 0.85), STROKE)
	draw_line(Vector2(size.x - 6, 6), Vector2(6, size.y - 6), Color(ink, 0.85), STROKE)
	var word: String = tr("table.confiscated").to_upper()
	var font: Font = ScreenKit.DISPLAY_BOLD
	var wide: Vector2 = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_SIZE)
	draw_set_transform(size / 2.0, STAMP_TILT)
	var band: Rect2 = Rect2(-wide / 2.0, wide).grow(BAND_PAD)
	draw_rect(band, ink)
	var baseline: Vector2 = Vector2(-wide.x / 2.0, font.get_ascent(STAMP_SIZE) - wide.y / 2.0)
	draw_string(font, baseline, word, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_SIZE, ScreenKit.PAPER)
	draw_set_transform(Vector2.ZERO, 0.0)

class_name LayoutMeasure
extends RefCounted
## How the walks' layout audit measures a text: where its ink lies on the screen, whether
## its own box cuts it, and the size its type is drawn at. Development only.

## Pixels a text may run past its box before it counts as cut.
const SLACK: float = 2.0


## Where a text's ink lies on the screen, as near as its font and alignment tell.
static func text_box(control: Control) -> Rect2:
	var label: Label = control as Label
	if label == null:
		var rich: RichTextLabel = control as RichTextLabel
		var tall: float = control.size.y
		if rich != null:
			tall = minf(tall, float(rich.get_content_height()))
		return global_rect(control, Rect2(Vector2.ZERO, Vector2(control.size.x, tall)))
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var wide: float = -1.0 if label.autowrap_mode == TextServer.AUTOWRAP_OFF else label.size.x
	var block: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size
	)
	block = Vector2(minf(block.x, label.size.x), minf(block.y, label.size.y))
	var at: Vector2 = Vector2.ZERO
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		at.x = (label.size.x - block.x) / 2.0
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		at.x = label.size.x - block.x
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		at.y = (label.size.y - block.y) / 2.0
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		at.y = label.size.y - block.y
	return global_rect(control, Rect2(at, block))


## Why a text is cut off by its own box, or empty when it is whole.
static func cut(control: Control) -> String:
	var label: Label = control as Label
	if label != null:
		var lines: int = label.get_line_count()
		var shown: int = label.get_visible_line_count()
		if shown < lines:
			return "shows %d of %d lines" % [shown, lines]
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.clip_text:
			var font: Font = label.get_theme_font("font")
			var needs: float = (
				font
				. get_string_size(
					label.text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					label.get_theme_font_size("font_size")
				)
				. x
			)
			if needs > label.size.x + SLACK:
				return "needs %d px, has %d" % [roundi(needs), roundi(label.size.x)]
		return ""
	var rich: RichTextLabel = control as RichTextLabel
	if rich != null and not rich.scroll_active and not rich.fit_content:
		var tall: int = rich.get_content_height()
		if tall > rich.size.y + SLACK:
			return "needs %d px of height, has %d" % [tall, roundi(rich.size.y)]
	var button: Button = control as Button
	if button != null and button.clip_text:
		var face: Font = button.get_theme_font("font")
		var wants: float = (
			face
			. get_string_size(
				button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")
			)
			. x
		)
		if wants > button.size.x + SLACK:
			return "needs %d px, has %d" % [roundi(wants), roundi(button.size.x)]
	return ""


## The type's size as drawn, its scale counted, or 0 for a text with no one size.
static func type_size(control: Control) -> float:
	var size_name: String = "font_size"
	if control is RichTextLabel:
		size_name = "normal_font_size"
	var scale: Vector2 = control.get_global_transform().get_scale()
	return control.get_theme_font_size(size_name) * minf(scale.x, scale.y)


## A rect in control's space, on the screen.
static func global_rect(control: Control, rect: Rect2) -> Rect2:
	return control.get_global_transform() * rect

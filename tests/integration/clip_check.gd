class_name ClipCheck
extends RefCounted
## What "without clipping" means in the tests (ADR 0034), for any tree of controls:
## every visible control sits inside the visible area; no single line of text is wider
## than its box; no wrapped label has more lines than it shows, and no rich text outside
## a scroll is taller than its box; and nothing the player reads is set under the least
## text size. Inside a ScrollContainer only width counts, since the text scrolls into
## view; the scroll itself must sit on screen.

## Sub-pixel rounding allowance, in canvas pixels.
const SLACK: float = 1.5


## Checks node and everything under it, adding each problem to problems.
static func check(
	node: Node, where: String, problems: PackedStringArray, scrolled: bool = false
) -> void:
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return
		_check_control(control, where, problems, scrolled)
	var inside: bool = scrolled or node is ScrollContainer
	for child: Node in node.get_children():
		check(child, where, problems, inside)


static func _check_control(
	control: Control, where: String, problems: PackedStringArray, scrolled: bool
) -> void:
	var visible: Rect2 = control.get_viewport().get_visible_rect().grow(SLACK)
	var rect: Rect2 = control.get_global_rect()
	var drawn: bool = rect.size.x > 0.0 and rect.size.y > 0.0 and control.modulate.a > 0.0
	var offscreen: bool = not visible.encloses(rect) and not _is_backdrop(control)
	var path: NodePath = control.get_path()
	if drawn and offscreen and not scrolled:
		problems.append("%s: %s at %s" % [where, path, rect])
	var overflow: float = text_overflow(control)
	if overflow > SLACK:
		problems.append("%s: %s text %.0f px too wide" % [where, path, overflow])
	if not scrolled and hidden_lines(control) > 0:
		problems.append("%s: %s hides %d lines" % [where, path, hidden_lines(control)])
	var font_size: int = read_size(control)
	if font_size > 0 and font_size < TextSize.PARAMS.least_text_px:
		problems.append("%s: %s set at %d px" % [where, path, font_size])


## How far single-line text runs past its control's width, or 0.
static func text_overflow(control: Control) -> float:
	var label: Label = control as Label
	if (
		label != null
		and label.autowrap_mode == TextServer.AUTOWRAP_OFF
		and not label.text.is_empty()
	):
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var width: float = 0.0
		for line: String in label.text.split("\n"):
			width = maxf(
				width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
		return width - label.size.x
	var button: Button = control as Button
	if button != null and not button.text.is_empty() and not button.clip_text:
		return button.get_combined_minimum_size().x - button.size.x
	return 0.0


## How many lines of wrapped text its box leaves out: a label's lines past those it
## shows, or for rich text, any content taller than its box.
static func hidden_lines(control: Control) -> int:
	var label: Label = control as Label
	if (
		label != null
		and label.autowrap_mode != TextServer.AUTOWRAP_OFF
		and not label.text.is_empty()
	):
		return maxi(label.get_line_count() - label.get_visible_line_count(), 0)
	var rich: RichTextLabel = control as RichTextLabel
	if rich != null and not rich.get_parsed_text().is_empty():
		return 1 if rich.get_content_height() > rich.size.y + SLACK else 0
	return 0


## The font size text is set at in a control that prints text, or 0.
static func read_size(control: Control) -> int:
	var label: Label = control as Label
	if label != null and not label.text.is_empty():
		return label.get_theme_font_size("font_size")
	var button: Button = control as Button
	if button != null and not button.text.is_empty():
		return button.get_theme_font_size("font_size")
	var rich: RichTextLabel = control as RichTextLabel
	if rich != null and not rich.get_parsed_text().is_empty():
		return rich.get_theme_font_size("normal_font_size")
	return 0


## Full-screen art and the offscreen card-pool parent are allowed past the edges.
static func _is_backdrop(control: Control) -> bool:
	if control is TextureRect or control is ColorRect:
		return true
	return control.get_global_rect().position.x < -1000.0

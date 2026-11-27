class_name ColumnMeasure
extends RefCounted
## How tall a column of labels and other pieces will stand before it is laid out, its
## wrapping labels measured from their fonts at a given width, so a paper of fixed size
## can pick its type sizes before the layout runs.


## How tall column stands with its wrapping labels set wide: its pieces and the gaps
## between them, without padding.
static func height(column: VBoxContainer, wide: float) -> float:
	var tall: float = 0.0
	var gap: float = float(column.get_theme_constant("separation"))
	for child: Node in column.get_children():
		var piece: Control = child as Control
		var label: Label = piece as Label
		if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			tall += wrapped_height(label, wide) + gap
		else:
			tall += piece.get_combined_minimum_size().y + gap
	return tall - gap


## How tall a label wrapping between words stands at width wide, from its font.
static func wrapped_height(label: Label, wide: float) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var spacing: float = float(label.get_theme_constant("line_spacing"))
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var block: Vector2 = font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size, -1, flags
	)
	var rows: int = maxi(roundi(block.y / font.get_height(font_size)), 1)
	return rows * font.get_height(font_size) + (rows - 1) * spacing

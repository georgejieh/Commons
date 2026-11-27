class_name PageFit
extends RefCounted
## How a page built by ScreenKit.page makes room at a larger text size (ADR 0034): its
## margin gives way first, then the gaps between its rows, each no further than its least.

## On a page that would overflow at a larger text size, its margin gives way first, to this
## many pixels at least (ADR 0034).
const LEAST_PAGE_MARGIN: int = 24
## The share of each gap between a page's rows that the gaps keep at the least, on the same pages.
const LEAST_GAP_SHARE: float = 0.5
## The meta key a column keeps its unsqueezed gap under, so a squeeze can be undone.
const FULL_GAP: StringName = &"full_gap"


## Shrinks a page's margin, then the gaps between its rows, as far as it must for what
## is on it to fit the screen, and no further than LEAST_PAGE_MARGIN and LEAST_GAP_SHARE.
## A page that fits keeps its full margin and gaps.
static func give_way(root: Control, margin: MarginContainer, column: VBoxContainer) -> void:
	if root.size.x <= 0.0 or root.size.y <= 0.0:
		return
	if not column.has_meta(FULL_GAP):
		column.set_meta(FULL_GAP, column.get_theme_constant("separation"))
	var full_gap: int = column.get_meta(FULL_GAP)
	var gaps: int = maxi(_shown_rows(column) - 1, 0)
	var shown_gap: int = column.get_theme_constant("separation")
	var need: Vector2 = column.get_combined_minimum_size()
	var content_tall: float = need.y - shown_gap * gaps
	var side: int = _room(root.size.x - need.x)
	var top: int = _room(root.size.y - content_tall - full_gap * gaps)
	var gap: int = full_gap
	if gaps > 0 and top == LEAST_PAGE_MARGIN:
		var spare: float = (root.size.y - content_tall - LEAST_PAGE_MARGIN * 2.0) / gaps
		var least_gap: int = ceili(full_gap * LEAST_GAP_SHARE)
		gap = clampi(floori(spare), least_gap, full_gap)
	_set_constant(margin, "margin_left", side)
	_set_constant(margin, "margin_right", side)
	_set_constant(margin, "margin_top", top)
	_set_constant(margin, "margin_bottom", top)
	_set_constant(column, "separation", gap)


## The margin a side keeps with spare room left over at the full margin.
static func _room(spare: float) -> int:
	return clampi(floori(spare / 2.0), LEAST_PAGE_MARGIN, ScreenKit.PAGE_MARGIN)


static func _shown_rows(column: VBoxContainer) -> int:
	var rows: int = 0
	for child: Node in column.get_children():
		if child is Control and (child as Control).visible:
			rows += 1
	return rows


## Sets a constant only when it changes, so a layout that settles stays settled.
static func _set_constant(control: Control, constant: String, value: int) -> void:
	if control.get_theme_constant(constant) != value:
		control.add_theme_constant_override(constant, value)

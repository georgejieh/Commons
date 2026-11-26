class_name SheetPad
extends RefCounted
## One padding inside a dialog's sheet: what stands on a verdict, summary, notice
## or menu sheet keeps the same clear room inside the sheet's printed inner rule as the
## page sheets keep, so no headline, line or tile touches the rule. The sheet keeps its
## card stock and border; only the room inside grows.

## Where the card stock's printed lines end, in from its edge, and the clear room kept
## inside them.
const RULE: int = 17
const CLEAR: int = 13
const INSET: int = RULE + CLEAR
## How wide a sheet over the notice wall's board stands: past the board's right edge.
const BOARD_WIDTH: float = 1040.0
## The wall's blank board, as shares of the picture, for tests.
const BOARD: Rect2 = Rect2(0.05, 0.1, 0.33, 0.8)


## Gives a sheet (a ScreenKit card's panel) the dialog padding on every side.
static func apply(panel: Control) -> void:
	panel.add_theme_stylebox_override("panel", ScreenKit.paper_style(INSET))


## The same for the sheet holding column, as ScreenKit.card makes it.
static func column(sheet: VBoxContainer) -> VBoxContainer:
	apply(ScreenKit.card_panel(sheet))
	return sheet


## A dialog sheet over the notice wall, for a verdict or a record read between rounds:
## down the left side, over the wall's own blank board, so no empty board shows beside
## it, at the page's least margin so a taller window's crop shows no strip of it either,
## with what is on it in the sheet's middle.
static func over_board(root: Control, width: float) -> VBoxContainer:
	var sheet: VBoxContainer = ScreenKit.side_sheet(root, ScreenKit.ART.notice_wall, width)
	sheet.alignment = BoxContainer.ALIGNMENT_CENTER
	var panel: Control = ScreenKit.card_panel(sheet)
	panel.offset_left = ScreenKit.LEAST_PAGE_MARGIN
	panel.offset_right = ScreenKit.LEAST_PAGE_MARGIN + width
	return column(sheet)

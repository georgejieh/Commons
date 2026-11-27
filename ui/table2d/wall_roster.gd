class_name WallRoster
extends PanelContainer
## The brigade's roster pinned on the wall under the right seat: every founding family's
## surname, typed in two columns on worn paper. On a corrupted profile names leave it as
## Famine rises, one after another in a fixed order that skips about the sheet, each fading
## to a scraped patch of paper. It is decoration: nothing the player reads at the table
## comes from it, and it gives way to the rules slip when the column needs the room
## (TableColumns).

const NAME_SIZE: int = 16
## Inside the paper's printed border.
const PADDING: int = 22
const COLUMNS: int = 2
const COLUMN_GAP: int = 28
## Names leave in steps of this many down the list, so the gaps do not run down one
## column; it shares no factor with the number of families.
const VANISH_STEP: int = 5
## The stain left where a name was scraped off, at its darkest.
const SCRAPED: Color = Color(0.35, 0.24, 0.12, 0.16)
## A name's ink is set again only when it moves by more than this.
const INK_STEP: float = 0.01

var _names: Array[Label] = []
var _patches: Array[StyleBoxFlat] = []
## Each name's place in the order they leave.
var _order: PackedInt32Array = PackedInt32Array()
var _ink: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	add_theme_stylebox_override("panel", ScreenKit.paper_style(PADDING))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(ScreenKit.eyebrow(tr("dread.roster")))
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", COLUMN_GAP)
	column.add_child(grid)
	var families: Array[FamilyDef] = []
	families.assign(RunDefaults.VILLAGE.families)
	_order.resize(families.size())
	_ink.resize(families.size())
	for index: int in families.size():
		grid.add_child(_name_label(tr(families[index].name_key)))
		_order[posmod(index * VANISH_STEP, families.size())] = index
		_ink[index] = 1.0


## Fades names off the roster for the roster effect's weight. No allocation.
func show_weight(weight: float, tuning: DreadEffects) -> void:
	var gone: float = tuning.names_gone(weight, _names.size())
	var worn: float = BowlGrime.wear()
	for index: int in _names.size():
		var ink: float = 1.0 - clampf(gone - _order[index], 0.0, 1.0)
		var near: bool = absf(ink - _ink[index]) <= INK_STEP and ink > 0.0 and ink < 1.0
		if ink == _ink[index] or near:
			continue
		_ink[index] = ink
		var typed: Color = BowlGrime.faded(ScreenKit.INK, worn)
		_names[index].add_theme_color_override("font_color", Color(typed, ink))
		_patches[index].bg_color = Color(SCRAPED, SCRAPED.a * (1.0 - ink))


## How many names still read, half their ink or more, for tests.
func names_left() -> int:
	var left: int = 0
	for ink: float in _ink:
		if ink >= 0.5:
			left += 1
	return left


func name_count() -> int:
	return _names.size()


func _name_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ScreenKit.TYPEWRITER)
	label.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	label.add_theme_color_override("font_color", BowlGrime.faded(ScreenKit.INK, BowlGrime.wear()))
	var patch: StyleBoxFlat = StyleBoxFlat.new()
	patch.bg_color = Color(SCRAPED, 0.0)
	label.add_theme_stylebox_override("normal", patch)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_names.append(label)
	_patches.append(patch)
	return label

class_name CardBackRow
extends VBoxContainer
## Settings' card back row (ADR 0025): every design as a swatch on aged paper, an open
## one drawn by the code-drawn back in its own inks with its name under it, the chosen one
## ringed in red. A design not yet open is a blank sheet saying only when it opens. Mouse,
## keyboard and gamepad pick a swatch; the choice applies at once and the screen saves it.

## The size of a design's sheet, in pixels.
const SWATCH: Vector2 = Vector2(176, 214)
## The size a card back is drawn at on its sheet, in pixels.
const BACK_SIZE: Vector2 = Vector2(88, 124)
## The size of a design's name, at Standard text.
const NAME_SIZE: int = 20

var _swatches: Array[AgedSheet] = []
## Each swatch's design ID, or "" for a locked one.
var _ids: Array[String] = []


func _init(finished_runs: int = 0) -> void:
	add_theme_constant_override("separation", 14)
	add_child(ScreenKit.eyebrow(tr("settings.card_back")))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var choice: CardBackDef = CardBacks.chosen(CardBacks.choice(), finished_runs)
	for index: int in CardBacks.POOL.backs.size():
		var design: CardBackDef = CardBacks.POOL.backs[index]
		var sheet: AgedSheet
		if CardBacks.is_open(design, finished_runs):
			sheet = _open_sheet(design, index)
			sheet.selected = design == choice
			sheet.chosen.connect(_choose.bind(design.id))
			_ids.append(design.id)
		else:
			sheet = AgedSheet.blank(CardBacks.locked_line(design, finished_runs), SWATCH, index)
			_ids.append("")
		row.add_child(sheet)
		_swatches.append(sheet)
	add_child(row)


## Every swatch in order, open and locked, for tests.
func swatches() -> Array[AgedSheet]:
	return _swatches.duplicate()


## Each swatch's design ID, "" where it is locked.
func ids() -> Array[String]:
	return _ids.duplicate()


func _open_sheet(design: CardBackDef, index: int) -> AgedSheet:
	var sheet: AgedSheet = AgedSheet.new(SWATCH.x, index)
	sheet.custom_minimum_size = SWATCH
	sheet.choosable = true
	var title: String = tr(design.name_key)
	sheet.accessibility_name = title
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var back: CardBack = CardBack.new(BACK_SIZE)
	back.design = design
	holder.add_child(back)
	sheet.column().add_child(holder)
	var label: Label = ScreenKit.label(title, NAME_SIZE, ScreenKit.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.column().add_child(label)
	return sheet


func _choose(back_id: String) -> void:
	Settings.set_value(CardBacks.SETTING, back_id)
	for index: int in _swatches.size():
		_swatches[index].selected = _ids[index] == back_id

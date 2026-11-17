class_name CheatSheet
extends Control
## The always-available rules card (P3B.5): every hand type with a small example and its
## Rate at the run's level for it, naming the level once a Directive has raised it, the
## rule changes active now, the current rank order, low to high, and while a rank is wild
## a section on wild cards (ADR 0029). While open it
## redraws on every run event, so a changed rule shows the frame it changes.

const TYPES: Array[String] = [
	"single",
	"pair",
	"trio",
	"trio_single",
	"trio_pair",
	"straight",
	"pair_chain",
	"airplane",
	"airplane_singles",
	"airplane_pairs",
	"four_two_singles",
	"four_two_pairs",
	"bomb",
	"rocket",
]

## How dark the table goes behind the open card.
## The keywords the sheet spells out; the rest explain themselves on hover.
const WORDS: PackedStringArray = ["grain", "rate", "zeal", "commons", "kitty", "kicker"]
const DIM: Color = Color(0.05, 0.03, 0.02, 0.72)
## The wild ranks' section in the smallest rules type, and the sheet's spacing while it
## shows, so the sheet still fits 1080 with every part of it shown.
const WILD_SIZE: int = 16
const SPACING: int = 14
const WILD_SPACING: int = 8

var _controller: RunController
var _types: GridContainer = GridContainer.new()
## Each hand type's Rate, in TYPES order.
var _rates: Array[Label] = []
var _active: Label = Label.new()
var _order: Label = Label.new()
## Shown only while a rank is wild (ADR 0029): its heading and its rules.
var _wild_head: Label
var _wild: Label = Label.new()
var _close: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sheet: VBoxContainer = ScreenKit.card(Vector2(1100, 0))
	sheet.add_theme_constant_override("separation", SPACING)
	sheet.add_child(ScreenKit.header(tr("cheat.eyebrow"), tr("cheat.title"), ScreenKit.INK))
	_types.columns = 6
	_types.add_theme_constant_override("h_separation", 28)
	_types.add_theme_constant_override("v_separation", 6)
	sheet.add_child(_types)
	sheet.add_child(ScreenKit.eyebrow(tr("cheat.active")))
	for label: Label in [_active, _order]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(840, 0)
		label.add_theme_font_size_override("font_size", 22)
	sheet.add_child(_active)
	sheet.add_child(_order)
	_wild_head = ScreenKit.eyebrow(tr("cheat.wild"))
	_wild.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wild.custom_minimum_size = Vector2(840, 0)
	_wild.add_theme_font_size_override("font_size", WILD_SIZE)
	for part: Control in [_wild_head, _wild]:
		part.visible = false
		sheet.add_child(part)
	sheet.add_child(ScreenKit.eyebrow(tr("cheat.keywords")))
	var words: Label = ScreenKit.label(Keywords.glossary(WORDS, false), 18)
	words.custom_minimum_size = Vector2(840, 0)
	sheet.add_child(words)
	_close = ScreenKit.button(tr("cheat.close"), CommonsTheme.PRIMARY)
	_close.pressed.connect(func() -> void: visible = false)
	sheet.add_child(_close)
	center.add_child(ScreenKit.card_panel(sheet))
	visible = false


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		visible = false
		accept_event()


func toggle(controller: RunController) -> void:
	if _controller == null:
		_controller = controller
		_controller.event_emitted.connect(func(_event: RunEvent) -> void: refresh())
	visible = not visible
	if visible:
		move_to_front()
		UiMotion.enter([self] as Array[Control])
	refresh()


func refresh() -> void:
	if not visible or _controller == null:
		return
	if _types.get_child_count() == 0:
		for type: String in TYPES:
			var name: Label = ScreenKit.label(tr("pattern." + type), 22)
			name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
			name.autowrap_mode = TextServer.AUTOWRAP_OFF
			_types.add_child(name)
			var example: Label = ScreenKit.label(tr("cheat.example." + type), 20)
			example.add_theme_font_override("font", ScreenKit.TYPEWRITER)
			example.autowrap_mode = TextServer.AUTOWRAP_OFF
			_types.add_child(example)
			var rate: Label = ScreenKit.label("", 20, Color(Keywords.INKS["rate"]))
			rate.autowrap_mode = TextServer.AUTOWRAP_OFF
			_types.add_child(rate)
			_rates.append(rate)
	for index: int in TYPES.size():
		_rates[index].text = _rate_text(index + 1)
	var active: PackedStringArray = []
	for modifier_id: String in _controller.active_modifier_ids():
		active.append(
			(
				"%s: %s"
				% [_controller.modifier_name(modifier_id), _controller.modifier_text(modifier_id)]
			)
		)
	if active.is_empty():
		active.append(tr("cheat.none"))
	_active.text = "\n".join(active)
	_order.text = tr("cheat.order").format({"order": " < ".join(_rank_order())})
	_show_wild()


## The wild ranks' section, while one is in force: which ranks, what a wild card may stand
## in for, the bomb order, bigger bombs under Industrialization and where Grain comes from.
func _show_wild() -> void:
	var ranks: Array[int] = _controller.wild_ranks()
	_wild_head.visible = not ranks.is_empty()
	_wild.visible = _wild_head.visible
	var spacing: int = WILD_SPACING if _wild.visible else SPACING
	var sheet: VBoxContainer = _wild.get_parent() as VBoxContainer
	sheet.add_theme_constant_override("separation", spacing)
	if ranks.is_empty():
		_wild.text = ""
		return
	var lines: PackedStringArray = [
		"%s. %s" % [ReadingText.wild_line(ranks), tr("cheat.wild.stand_in")],
		"%s %s" % [tr("cheat.wild.order"), tr("cheat.wild.grain")],
	]
	if _controller.big_bombs():
		lines.append(tr("cheat.wild.big"))
	_wild.text = "\n".join(lines)


## The wild ranks' section as shown, or empty while it is hidden, for tests.
func wild_text() -> String:
	return _wild.text if _wild.visible else ""


## A hand type's Rate at the run's level for it, with the level once it is above the
## first. type is a Pattern.Type value.
func _rate_text(type: int) -> String:
	var level: int = _controller.hand_level(type)
	var rate: int = _controller.hand_rate(type, level)
	if level > 1:
		return tr("cheat.rate.level").format({"rate": rate, "level": level})
	return tr("cheat.rate").format({"rate": rate})


## The Rate shown for a hand type, a Pattern.Type value, for tests.
func rate_text(type: int) -> String:
	return _rates[type - 1].text


## The Close button, which the arrival points at (ADR 0026).
func close_button() -> Button:
	return _close


func rank_order_text() -> String:
	return _order.text


func active_text() -> String:
	return _active.text


func _rank_order() -> PackedStringArray:
	var rank_map: PackedByteArray = _controller.player_table().rank_map
	var ranks: Array[int] = []
	for rank: int in Ranks.COUNT:
		ranks.append(rank)
	ranks.sort_custom(func(a: int, b: int) -> bool: return rank_map[a] < rank_map[b])
	var glyphs: PackedStringArray = []
	for rank: int in ranks:
		glyphs.append(tr(CardView.RANK_KEYS[rank]))
	return glyphs

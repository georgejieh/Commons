class_name CheatSheet
extends Control
## The always-available rules card (P3B.5): every hand type with a small example, the
## rule changes active now, and the current rank order, low to high. While open it
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
const WORDS: PackedStringArray = ["grain", "zeal", "commons", "kitty", "kicker"]
const DIM: Color = Color(0.05, 0.03, 0.02, 0.72)

var _controller: RunController
var _types: GridContainer = GridContainer.new()
var _active: Label = Label.new()
var _order: Label = Label.new()


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
	var sheet: VBoxContainer = ScreenKit.card(Vector2(900, 0))
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(ScreenKit.header(tr("cheat.eyebrow"), tr("cheat.title"), ScreenKit.INK))
	_types.columns = 4
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
	sheet.add_child(ScreenKit.eyebrow(tr("cheat.keywords")))
	var words: Label = ScreenKit.label(Keywords.glossary(WORDS), 20)
	words.custom_minimum_size = Vector2(840, 0)
	sheet.add_child(words)
	var close: Button = ScreenKit.button(tr("cheat.close"), CommonsTheme.PRIMARY)
	close.pressed.connect(func() -> void: visible = false)
	sheet.add_child(close)
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
	var active: PackedStringArray = []
	for modifier_id: String in _controller.active_modifier_ids():
		active.append(
			(
				"%s: %s"
				% [tr("modifier.%s.name" % modifier_id), _controller.modifier_text(modifier_id)]
			)
		)
	if active.is_empty():
		active.append(tr("cheat.none"))
	_active.text = "\n".join(active)
	_order.text = tr("cheat.order").format({"order": " < ".join(_rank_order())})


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

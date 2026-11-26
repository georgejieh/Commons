class_name CheatSheet
extends Control
## The always-available rules card: every hand type with a small example and its Rate at
## the run's level for it, naming the level once a Directive has raised it, the rule
## changes active now, the current rank order, low to high, and while a rank is wild a
## section on wild cards (ADR 0029). While open it redraws on every run event, so a changed
## rule shows the frame it changes. A sheet with more rules than the screen has room for
## scrolls between its heading and Close, never cut off and never drawn smaller (ADR 0034).

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

## The keywords the sheet spells out; the rest explain themselves on hover.
const WORDS: PackedStringArray = ["grain", "rate", "zeal", "commons", "kitty", "kicker"]
## How dark the table goes behind the open card.
const DIM: Color = Color(0.05, 0.03, 0.02, 0.72)
## The wild ranks' section in the smallest rules type, and the sheet's spacing while it
## shows, so the sheet still fits 1080 with every part of it shown.
const WILD_SIZE: int = 16
const SPACING: int = 14
const WILD_SPACING: int = 8
## The least room kept clear above and below the sheet, in pixels.
const MARGIN: float = 12.0

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
var _panel: Control
var _scroll: ProseScroll


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
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", SPACING)
	_scroll = ProseScroll.new(body)
	sheet.add_child(_scroll)
	_types.columns = 6
	_types.add_theme_constant_override("h_separation", 28)
	_types.add_theme_constant_override("v_separation", 6)
	body.add_child(_types)
	body.add_child(ScreenKit.eyebrow(tr("cheat.active")))
	for label: Label in [_active, _order]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(840, 0)
		label.add_theme_font_size_override("font_size", TextSize.px(22))
	body.add_child(_active)
	body.add_child(_order)
	_wild_head = ScreenKit.eyebrow(tr("cheat.wild"))
	_wild.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wild.custom_minimum_size = Vector2(840, 0)
	_wild.add_theme_font_size_override("font_size", TextSize.px(WILD_SIZE))
	for part: Control in [_wild_head, _wild]:
		part.visible = false
		body.add_child(part)
	body.add_child(ScreenKit.eyebrow(tr("cheat.keywords")))
	var words: Label = ScreenKit.label(Keywords.glossary(WORDS, false), 18)
	words.custom_minimum_size = Vector2(840, 0)
	body.add_child(words)
	_close = ScreenKit.button(tr("cheat.close"), CommonsTheme.PRIMARY)
	_close.pressed.connect(func() -> void: visible = false)
	sheet.add_child(_close)
	_panel = ScreenKit.card_panel(sheet)
	center.add_child(_panel)
	# A container lays its child out at full size, so the fit follows every layout.
	center.sort_children.connect(_fit)
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
	for modifier_id: String in _controller.items.active_modifier_ids():
		active.append(
			(
				"%s: %s"
				% [
					_controller.texts.modifier_name(modifier_id),
					_controller.texts.modifier_text(modifier_id)
				]
			)
		)
	# A boss twist holds for the whole Set (ADR 0043).
	var boss: String = _controller.items.boss()
	if not boss.is_empty():
		active.append(
			(
				"%s: %s"
				% [_controller.texts.modifier_name(boss), _controller.texts.modifier_text(boss)]
			)
		)
	# A Reform's rule for the player's seat, such as Industrialization, is in play too.
	for reform_id: String in _controller.items.table_rule_reforms():
		var rule: String = _controller.texts.reform_text(reform_id)
		active.append("%s: %s" % [_controller.texts.reform_name(reform_id), rule])
	if active.is_empty():
		active.append(tr("cheat.none"))
	_active.text = "\n".join(active)
	_order.text = tr("cheat.order").format({"order": " < ".join(_rank_order())})
	_show_wild()


## The wild ranks' section, while one is in force: which ranks, what the player's wild
## cards may stand in for and that a villager's are plain (ADR 0039), the bomb order, by
## size first under bigger bombs, and where Grain comes from.
func _show_wild() -> void:
	var ranks: Array[int] = _controller.table.wild_ranks()
	_wild_head.visible = not ranks.is_empty()
	_wild.visible = _wild_head.visible
	var spacing: int = WILD_SPACING if _wild.visible else SPACING
	var sheet: VBoxContainer = _wild.get_parent() as VBoxContainer
	sheet.add_theme_constant_override("separation", spacing)
	if ranks.is_empty():
		_wild.text = ""
		return
	var order: String = (
		"cheat.wild.order.big" if _controller.table.big_bombs() else "cheat.wild.order"
	)
	var lines: PackedStringArray = [
		"%s. %s" % [ReadingText.wild_line(ranks), tr("cheat.wild.stand_in")],
		"%s %s" % [tr(order), tr("cheat.wild.grain")],
	]
	_wild.text = "\n".join(lines)


## Lets the rules stand as tall as the screen leaves room for between the heading and
## Close, and scroll past that.
func _fit() -> void:
	var others: float = _panel.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	_scroll.fit_to(maxf(size.y - 2.0 * MARGIN - others, 0.0))


## The sheet's box on screen as drawn, for tests.
func sheet_rect() -> Rect2:
	return _panel.get_global_rect()


## The wild ranks' section as shown, or empty while it is hidden, for tests.
func wild_text() -> String:
	return _wild.text if _wild.visible else ""


## A hand type's Rate at the run's level for it, with the level once it is above the
## first. type is a Pattern.Type value.
func _rate_text(type: int) -> String:
	var level: int = _controller.figures.hand_level(type)
	var rate: int = _controller.figures.hand_rate(type, level)
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
	var rank_map: PackedByteArray = _controller.table.player_table().rank_map
	var ranks: Array[int] = []
	for rank: int in Ranks.COUNT:
		ranks.append(rank)
	ranks.sort_custom(func(a: int, b: int) -> bool: return rank_map[a] < rank_map[b])
	var glyphs: PackedStringArray = []
	for rank: int in ranks:
		glyphs.append(tr(CardView.RANK_KEYS[rank]))
	return glyphs

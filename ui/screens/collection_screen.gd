class_name CollectionScreen
extends Control
## The collection (P3B.9): every Cadre in both pools, with its art and rules text, under
## two headings, collective Cadres from the state store and private ones from the black
## market. The grids scroll, and the scroll follows keyboard and gamepad focus from card
## to card. Unlocks arrive with P4.14; until then every Cadre shows.

const POOL: CadrePool = preload("res://data/run/cadre_pool.tres")
const MARKET_POOL: CadrePool = preload("res://data/run/market_pool.tres")
const ART_SIZE: Vector2 = Vector2(128, 168)
const COLUMNS: int = 3
const CARD_WIDTH: float = 540.0
const RULES_WIDTH: float = 340.0
const FOCUS_RING: Color = Color("b98a2c")

var _entries: Array[Control] = []
var _scroll: ScrollContainer = ScrollContainer.new()


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	column.add_child(ScreenKit.header(tr("coll.eyebrow"), tr("coll.title"), ScreenKit.GOLD))
	var sections: VBoxContainer = VBoxContainer.new()
	sections.add_theme_constant_override("separation", 18)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_child(_heading(tr("coll.collective")))
	sections.add_child(_grid(POOL.cadres))
	sections.add_child(_heading(tr("coll.private")))
	sections.add_child(_grid(MARKET_POOL.cadres))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.add_child(sections)
	column.add_child(_scroll)
	var back: Button = ScreenKit.button(tr("coll.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


## The cards in order, collective then private, for tests.
func entries() -> Array[Control]:
	return _entries.duplicate()


func scroll() -> ScrollContainer:
	return _scroll


func _heading(text: String) -> Label:
	var heading: Label = ScreenKit.styled(text, CommonsTheme.TITLE)
	ScreenKit.paper_outline(heading)
	return heading


func _grid(cadres: Array[ModifierDef]) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	for definition: ModifierDef in cadres:
		var entry: Control = _entry(definition)
		grid.add_child(entry)
		_entries.append(entry)
	return grid


## One Cadre's card. It takes focus, so the arrows and the d-pad walk the grid and the
## scroll follows; a faded gold ring shows where focus is.
func _entry(definition: ModifierDef) -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(CARD_WIDTH, 0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var art: TextureRect = TextureRect.new()
	art.texture = ScreenKit.cadre_art(definition.id)
	art.custom_minimum_size = ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(art)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name: Label = ScreenKit.styled(tr(definition.name_key), CommonsTheme.TITLE)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(RULES_WIDTH, 0)
	words.add_child(name)
	var text: String = CadreText.rules(definition)
	if definition.table_wide:
		text += " " + tr("modifier.table_wide")
	var rules: Label = ScreenKit.label(text, 20)
	rules.custom_minimum_size = Vector2(RULES_WIDTH, 0)
	words.add_child(rules)
	row.add_child(words)
	sheet.add_child(row)
	var panel: Control = ScreenKit.card_panel(sheet)
	panel.focus_mode = Control.FOCUS_ALL
	panel.tooltip_text = Keywords.wrapped("%s\n%s" % [tr(definition.name_key), text])
	var ring: ReferenceRect = ReferenceRect.new()
	ring.editor_only = false
	ring.border_color = Color(BowlGrime.aged(FOCUS_RING, BowlGrime.wear() * 0.5), 0.9)
	ring.border_width = 3.0
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ring)
	panel.focus_entered.connect(ring.set_visible.bind(true))
	panel.focus_exited.connect(ring.set_visible.bind(false))
	UiMotion.hoverable(panel)
	return panel

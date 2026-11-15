class_name CollectionScreen
extends Control
## The collection (P3B.9): every Cadre in the pool, with its art and rules text, in a
## list that scrolls once both pools outgrow the screen. Unlocks arrive with P4.14; until
## then every Cadre shows.

const POOL: CadrePool = preload("res://data/run/cadre_pool.tres")
const MARKET_POOL: CadrePool = preload("res://data/run/market_pool.tres")
const ART_SIZE: Vector2 = Vector2(120, 150)
const COLUMNS: int = 4
const CARD_WIDTH: float = 400.0
const RULES_WIDTH: float = 220.0


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	column.add_child(ScreenKit.header(tr("coll.eyebrow"), tr("coll.title"), ScreenKit.GOLD))
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	for definition: ModifierDef in POOL.cadres + MARKET_POOL.cadres:
		grid.add_child(_entry(definition))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	column.add_child(scroll)
	var back: Button = ScreenKit.button(tr("coll.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


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
	words.add_child(ScreenKit.styled(tr(definition.name_key), CommonsTheme.TITLE))
	var rules: Label = ScreenKit.label(tr(definition.text_key).format(definition.text_values()), 20)
	rules.custom_minimum_size = Vector2(RULES_WIDTH, 0)
	words.add_child(rules)
	row.add_child(words)
	sheet.add_child(row)
	return ScreenKit.card_panel(sheet)

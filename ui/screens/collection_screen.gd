class_name CollectionScreen
extends Control
## The collection (P3B.9): every Cadre in the pool, with its art and rules text.
## Unlocks arrive with P4.14; until then every Cadre shows.

const POOL: CadrePool = preload("res://data/run/cadre_pool.tres")
const MARKET_POOL: CadrePool = preload("res://data/run/market_pool.tres")
const ART_SIZE: Vector2 = Vector2(120, 150)
const COLUMNS: int = 3


func open(app: DemoApp) -> void:
	var column: VBoxContainer = ScreenKit.page(self, ScreenKit.ART.notice_wall)
	column.add_child(ScreenKit.header(tr("coll.eyebrow"), tr("coll.title"), ScreenKit.GOLD))
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	for definition: ModifierDef in POOL.cadres + MARKET_POOL.cadres:
		grid.add_child(_entry(definition))
	column.add_child(grid)
	var back: Button = ScreenKit.button(tr("coll.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


func _entry(definition: ModifierDef) -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(520, 0))
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
	rules.custom_minimum_size = Vector2(340, 0)
	words.add_child(rules)
	row.add_child(words)
	sheet.add_child(row)
	return ScreenKit.card_panel(sheet)

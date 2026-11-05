extends GdUnitTestSuite
## The art itself changes with corruption (P3B.12, ADR 0018): each key asset resolves to
## its variant for the current stage, falling back to the nearest earlier stage, on
## every screen and on the table as the stage changes.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_art_stages/run.json"

var _app: DemoApp
var _early: Texture2D = PlaceholderTexture2D.new()
var _late: Texture2D = PlaceholderTexture2D.new()


func before_test() -> void:
	var surface: ArtVariant = ArtVariant.new()
	surface.base = ScreenKit.ART.table_surface
	surface.stages = [_early, null, null, null, null, null, null, null, null, _late]
	var back: ArtVariant = ArtVariant.new()
	back.base = ScreenKit.ART.card_back
	back.stages = [_early]
	ArtStages.variants_override = [surface, back]
	ArtStages.stage_override = 0
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	ArtStages.variants_override = []
	ArtStages.stage_override = -1
	Saves.run_service().delete()


func test_a_stage_falls_back_to_the_nearest_earlier_art() -> void:
	var surface: Texture2D = ScreenKit.ART.table_surface
	assert_object(ArtStages.resolve(surface, 0)).is_same(_early)
	assert_object(ArtStages.resolve(surface, 4)).is_same(_early)
	assert_object(ArtStages.resolve(surface, 9)).is_same(_late)
	assert_object(ArtStages.base_of(_late)).is_same(surface)
	var plain: Texture2D = ScreenKit.ART.title
	assert_object(ArtStages.resolve(plain, 9)).is_same(plain)
	var empty: ArtVariant = ArtVariant.new()
	empty.base = plain
	assert_object(empty.at(5)).is_same(plain)


func test_the_table_shows_the_stage_art_and_follows_a_stage_change() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var surface: TextureRect = table.get("_surface")
	assert_object(surface.texture).is_same(_early)
	var dread: DreadLayers = table.get("_dread")
	dread.force(10, 10, false, 9)
	assert_object(surface.texture).is_same(_late)
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	var back: TextureRect = seats[1].get("_back")
	assert_object(back.texture).is_same(_early)


func test_screens_built_later_use_the_new_stage() -> void:
	ArtStages.stage_override = 9
	var rect: TextureRect = auto_free(ScreenKit.cover(ScreenKit.ART.table_surface))
	assert_object(rect.texture).is_same(_late)

extends GdUnitTestSuite
## The art itself changes with corruption (P3B.12, ADR 0018): each key asset resolves to
## its variant for the current stage, falling back to the nearest earlier stage, on
## every screen and on the table as the stage changes.

const SEED: int = 4301
const SAVE_PATH: String = "user://test_art_stages/run.json"

const EARLY: String = "res://art/backdrops/stages/table_surface_s0.png"
const LATE: String = "res://art/backdrops/stages/table_surface_s4.png"
const BACK_EARLY: String = "res://art/cards/stages/card_back_s0.png"

var _app: DemoApp


func before_test() -> void:
	var surface: ArtVariant = ArtVariant.new()
	surface.base = ScreenKit.ART.table_surface
	surface.stage_paths = [EARLY, "", "", "", "", "", "", "", "", LATE]
	var back: ArtVariant = ArtVariant.new()
	back.base = ScreenKit.ART.card_back
	back.stage_paths = [BACK_EARLY]
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
	assert_str(ArtStages.resolve(surface, 0).resource_path).is_equal(EARLY)
	assert_str(ArtStages.resolve(surface, 4).resource_path).is_equal(EARLY)
	assert_str(ArtStages.resolve(surface, 9).resource_path).is_equal(LATE)
	assert_object(ArtStages.base_of(load(LATE))).is_same(surface)
	var plain: Texture2D = ScreenKit.ART.title
	assert_object(ArtStages.resolve(plain, 9)).is_same(plain)
	var empty: ArtVariant = ArtVariant.new()
	empty.base = plain
	assert_str(empty.path_at(5)).is_empty()


func test_the_table_shows_the_stage_art_and_follows_a_stage_change() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var surface: TextureRect = table.get("_surface")
	assert_str(Lighting.diffuse(surface.texture).resource_path).is_equal(EARLY)
	var dread: DreadLayers = table.get("_dread")
	dread.force(10, 10, false, 9)
	assert_str(Lighting.diffuse(surface.texture).resource_path).is_equal(LATE)
	var seats: Dictionary[int, SeatPanel] = table.get("_seats")
	var back: TextureRect = seats[1].get("_back")
	assert_str(back.texture.resource_path).is_equal(BACK_EARLY)


func test_the_shipped_variants_open_innocent_and_end_on_the_late_art() -> void:
	ArtStages.variants_override = []
	var last: int = BoardState.CORRUPTION_STAGES - 1
	for variant: ArtVariant in ArtStages.CONFIG.art:
		assert_int(variant.stage_paths.size()).is_less_equal(BoardState.CORRUPTION_STAGES)
		for path: String in variant.stage_paths:
			if not path.is_empty():
				assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		assert_object(ArtStages.resolve(variant.base, 0)).is_not_same(variant.base)
		assert_object(ArtStages.resolve(variant.base, last)).is_same(variant.base)


func test_only_the_stage_shown_is_loaded() -> void:
	ArtStages.variants_override = []
	ArtStages.stage_override = 0
	var unused: String = "res://art/backdrops/stages/title_s4.png"
	assert_bool(ResourceLoader.has_cached(unused)).is_false()
	var shown: Texture2D = ArtStages.resolve(ScreenKit.ART.title)
	assert_str(shown.resource_path).is_equal("res://art/backdrops/stages/title_s0.png")
	assert_bool(ResourceLoader.has_cached(unused)).is_false()


func test_screens_built_later_use_the_new_stage() -> void:
	ArtStages.stage_override = 9
	var rect: TextureRect = auto_free(ScreenKit.cover(ScreenKit.ART.table_surface))
	assert_str(rect.texture.resource_path).is_equal(LATE)

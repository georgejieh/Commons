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
		if variant.base == null:
			# A picture loaded on demand resolves by its file, never loading its base first.
			var early: Texture2D = ArtStages.picture(variant.base_path, 0)
			assert_str(early.resource_path).is_not_equal(variant.base_path)
			assert_str(ArtStages.picture(variant.base_path, last).resource_path).is_equal(
				variant.base_path
			)
			continue
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


func test_the_table_surface_is_lit_with_the_normal_map_for_its_stage() -> void:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var surface: TextureRect = table.get("_surface")
	var canvas: CanvasTexture = surface.texture as CanvasTexture
	assert_object(canvas).is_not_null()
	assert_str(canvas.normal_texture.resource_path).is_equal(
		"res://art/normals/table_surface_s0_n.png"
	)
	assert_int(surface.light_mask).is_equal(Lighting.MASK)


func test_screens_built_later_use_the_new_stage() -> void:
	ArtStages.stage_override = 9
	var rect: TextureRect = auto_free(ScreenKit.cover(ScreenKit.ART.table_surface))
	assert_str(rect.texture.resource_path).is_equal(LATE)


## Cadre and ending pictures load when shown, through a cache that holds at most its
## limit and drops the least recently shown; a dropped picture comes back when asked for.
func test_pictures_load_on_demand_and_the_cache_keeps_its_limit() -> void:
	ArtStages.variants_override = []
	ArtStages.stage_override = 0
	var cache: ArtCache = ArtStages.pictures()
	cache.clear()
	assert_int(ScreenKit.ART.picture_cache).is_equal(12)
	var ids: Array[String] = ScreenKit.ART.cadres.keys()
	assert_int(ids.size()).is_greater(cache.limit)
	var first: String = ""
	for cadre_id: String in ids:
		var shown: Texture2D = ScreenKit.cadre_art(cadre_id)
		assert_object(shown).override_failure_message(cadre_id).is_not_null()
		if first.is_empty():
			first = shown.resource_path
		assert_int(cache.held_count()).is_less_equal(cache.limit)
	assert_bool(cache.holds(first)).is_false()
	assert_str(ScreenKit.cadre_art(ids[0]).resource_path).is_equal(first)
	assert_bool(cache.holds(first)).is_true()
	assert_int(cache.held_count()).is_equal(cache.limit)


## The stage picks a Cadre's picture by its file: the first-run print early, the main
## file from its late stage, and nothing loaded for a stage not shown.
func test_a_cadre_picture_resolves_by_stage_from_its_path() -> void:
	ArtStages.variants_override = []
	ArtStages.pictures().clear()
	var main: String = ScreenKit.ART.cadre_path("iron_rice_bowl")
	var early: String = "res://art/cadres/stages/cadre_iron_rice_bowl_s0.png"
	ArtStages.stage_override = 3
	assert_str(ScreenKit.cadre_art("iron_rice_bowl").resource_path).is_equal(early)
	assert_bool(ResourceLoader.has_cached(main)).is_false()
	ArtStages.stage_override = 8
	assert_str(ScreenKit.cadre_art("iron_rice_bowl").resource_path).is_equal(main)
	assert_object(ScreenKit.ending_art("labeled")).is_not_null()
	assert_object(ScreenKit.cadre_art("no_such_cadre")).is_null()

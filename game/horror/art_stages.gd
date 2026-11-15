class_name ArtStages
extends RefCounted
## Picks every key asset's art for the hidden corruption stage (P3B.12, ADR 0018, ADR
## 0025). Screens ask for an asset by its base texture, or a Cadre or ending picture by
## its file, and get that stage's variant, so the art itself changes across a profile,
## under the meter layers' effects. Variant files load only when shown.
##
## The stage comes from the profile's corruption, latched when a run starts, at each
## round's start and on the title, and served unchanged in between, so it never moves
## inside a round. The horror-intensity setting caps the stage the art shows. Nothing
## outside this horror layer reads the value: screens ask for art, never for a number.

const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
const ART: ArtLibrary = preload("res://data/ui/art.tres")
const LAST_STAGE: int = BoardState.CORRUPTION_STAGES - 1
## Corruption points per stage: stage = floor(corruption / STAGE_SPAN), at most the last.
const STAGE_SPAN: float = 10.0
## Development builds only: a stage, or a corruption value 0 to 100, for the session.
const STAGE_FLAG: String = "--corruption-stage"
const VALUE_FLAG: String = "--corruption"
const INTENSITY_KEY: String = "horror_intensity"

## Tests and tools may set these; -1 and empty mean "use the real values".
static var stage_override: int = -1
static var variants_override: Array[ArtVariant] = []
static var intensity_override: float = -1.0

## The stage latched from the profile the last time the app read it.
static var _latched: int = 0
## The stage files loaded for one stage, held so a picture that leaves the screen and
## comes back mid-play is not read from disk again. Dropped when the stage changes.
static var _loaded: Dictionary[String, Texture2D] = {}
static var _loaded_stage: int = -1
## Cadre and ending pictures, loaded by file when shown.
static var _pictures: ArtCache = ArtCache.new(ART.picture_cache)


## The hidden corruption stage, 0 to 9: the override, then a development build's flags,
## then the stage latched from the profile.
static func stage() -> int:
	if stage_override >= 0:
		return mini(stage_override, LAST_STAGE)
	return stage_from(OS.is_debug_build(), OS.get_cmdline_user_args(), _latched)


## The stage from what a build was given: only a debug build reads the flags, the stage
## flag before the value flag. A release build always gets the latched stage.
static func stage_from(debug: bool, args: PackedStringArray, latched: int) -> int:
	if debug:
		var at: int = args.find(STAGE_FLAG)
		if at >= 0 and at + 1 < args.size():
			return clampi(args[at + 1].to_int(), 0, LAST_STAGE)
		at = args.find(VALUE_FLAG)
		if at >= 0 and at + 1 < args.size():
			return stage_of(args[at + 1].to_float())
	return clampi(latched, 0, LAST_STAGE)


## The stage a corruption value from 0 to 100 shows.
static func stage_of(corruption: float) -> int:
	return clampi(floori(corruption / STAGE_SPAN), 0, LAST_STAGE)


## Reads the profile's corruption and holds its stage until the next latch. The app calls
## this as a run starts, at each round's start and on the title, never inside a round.
static func latch(profile: SaveService) -> void:
	latch_value(Profile.read(profile).corruption)


static func latch_value(corruption: float) -> void:
	_latched = stage_of(corruption)


## The highest stage the art may show at a horror intensity from 0 to 1.
static func cap_for(intensity: float) -> int:
	return clampi(roundi(LAST_STAGE * clampf(intensity, 0.0, 1.0)), 0, LAST_STAGE)


## The stage the art shows: the stage, capped by the horror-intensity setting.
static func art_stage() -> int:
	return mini(stage(), cap_for(intensity()))


## The horror-intensity setting, 1 when no settings are loaded.
static func intensity() -> float:
	if intensity_override >= 0.0:
		return intensity_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var settings: Node = null if tree == null else tree.root.get_node_or_null("Settings")
	if settings == null:
		return 1.0
	return float(settings.call("value", INTENSITY_KEY))


## The art to show for texture at a stage (the current one when -1), never above the
## intensity's cap. Textures with no variants come back unchanged.
static func resolve(texture: Texture2D, at_stage: int = -1) -> Texture2D:
	if texture == null:
		return null
	var variant: ArtVariant = _variant_for(texture)
	if variant == null:
		return texture
	var shown_stage: int = _shown(at_stage)
	var path: String = variant.path_at(shown_stage)
	if path.is_empty():
		return variant.base if variant.base != null else _pictures.picture(variant.base_path)
	if _loaded_stage != shown_stage:
		_loaded.clear()
		_loaded_stage = shown_stage
	if not _loaded.has(path):
		_loaded[path] = load(path)
	return _loaded[path]


## A Cadre's or an ending's picture by its file, at a stage (the current one when -1),
## loaded on demand through the picture cache. Null for an empty path.
static func picture(path: String, at_stage: int = -1) -> Texture2D:
	if path.is_empty():
		return null
	var variant: ArtVariant = _variant_by_path(path)
	if variant == null:
		return _pictures.picture(path)
	var shown: String = variant.path_at(_shown(at_stage))
	return _pictures.picture(variant.base_file() if shown.is_empty() else shown)


## Lets go of every picture and stage file held, as the app closes, so none outlives it.
static func release() -> void:
	_pictures.clear()
	_loaded.clear()
	_loaded_stage = -1


## The pictures loaded on demand, for tests and tools.
static func pictures() -> ArtCache:
	return _pictures


## The base asset a shown texture came from, or the texture itself.
static func base_of(texture: Texture2D) -> Texture2D:
	var variant: ArtVariant = _variant_for(texture)
	if variant == null or variant.base == null:
		return texture
	return variant.base


static func _shown(at_stage: int) -> int:
	var wanted: int = stage() if at_stage < 0 else at_stage
	return mini(wanted, cap_for(intensity()))


static func _variants() -> Array[ArtVariant]:
	return variants_override if not variants_override.is_empty() else CONFIG.art


static func _variant_for(texture: Texture2D) -> ArtVariant:
	for variant: ArtVariant in _variants():
		if variant.base != null and variant.base == texture:
			return variant
	return _variant_by_path(texture.resource_path)


static func _variant_by_path(path: String) -> ArtVariant:
	if path.is_empty():
		return null
	for variant: ArtVariant in _variants():
		if variant.base_file() == path or variant.has_path(path):
			return variant
	return null

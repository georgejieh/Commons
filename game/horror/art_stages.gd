class_name ArtStages
extends RefCounted
## Picks every key asset's art for the hidden corruption stage (P3B.12, ADR 0018).
## Screens ask for an asset by its base texture and get that stage's variant, so the art
## itself changes across a profile, under the meter layers' effects. Variant files load
## only when shown. Stages change only
## when a screen is built or the table refreshes at a round boundary.

const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")

## Tests and tools may set these; -1 and empty mean "use the real values".
static var stage_override: int = -1
static var variants_override: Array[ArtVariant] = []

## The stage files loaded for one stage, held so a picture that leaves the screen and
## comes back mid-play is not read from disk again. Dropped when the stage changes.
static var _loaded: Dictionary[String, Texture2D] = {}
static var _loaded_stage: int = -1


## The hidden corruption stage, 0 to 9. It stays 0 until the profile save holds it;
## a development build can pass --corruption-stage N to check each stage.
static func stage() -> int:
	if stage_override >= 0:
		return stage_override
	if not OS.is_debug_build():
		return 0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--corruption-stage")
	if at >= 0 and at + 1 < args.size():
		return clampi(args[at + 1].to_int(), 0, BoardState.CORRUPTION_STAGES - 1)
	return 0


## The art to show for texture at a stage (the current one when -1). Textures with no
## variants come back unchanged.
static func resolve(texture: Texture2D, at_stage: int = -1) -> Texture2D:
	if texture == null:
		return null
	var variant: ArtVariant = _variant_for(texture)
	if variant == null:
		return texture
	var shown_stage: int = stage() if at_stage < 0 else at_stage
	var path: String = variant.path_at(shown_stage)
	if path.is_empty():
		return variant.base
	if shown_stage != _loaded_stage:
		_loaded.clear()
		_loaded_stage = shown_stage
	if not _loaded.has(path):
		_loaded[path] = load(path)
	return _loaded[path]


## The base asset a shown texture came from, or the texture itself.
static func base_of(texture: Texture2D) -> Texture2D:
	var variant: ArtVariant = _variant_for(texture)
	return texture if variant == null else variant.base


static func _variant_for(texture: Texture2D) -> ArtVariant:
	var variants: Array[ArtVariant] = (
		variants_override if not variants_override.is_empty() else CONFIG.art
	)
	for variant: ArtVariant in variants:
		if variant.base == texture or variant.has_path(texture.resource_path):
			return variant
	return null

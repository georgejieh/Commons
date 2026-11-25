class_name ScriptCheck
extends RefCounted
## Finds project scripts that do not compile, which no other gate catches:
## tests load only what they use, and exports tokenize without type checking.

const SKIPPED_FOLDERS: PackedStringArray = [
	"res://.godot",
	"res://.claude",
	"res://.git",
	"res://addons",
	"res://build",
	"res://reports",
	"res://tests/fixtures",
]


## Every script under root, skipping vendored code and deliberately broken fixtures.
static func scripts_under(root: String) -> PackedStringArray:
	return ToolFiles.under(root, ["gd"], SKIPPED_FOLDERS)


## True when the script at path loads and compiles.
static func compiles(path: String) -> bool:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	var script: GDScript = resource as GDScript
	return script != null and script.can_instantiate()

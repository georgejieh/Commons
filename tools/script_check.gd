class_name ScriptCheck
extends RefCounted
## Finds project scripts that do not compile, which no other gate catches:
## tests load only what they use, and exports tokenize without type checking.

const SKIPPED_FOLDERS: PackedStringArray = [
	"res://.godot",
	"res://.git",
	"res://addons",
	"res://build",
	"res://reports",
	"res://tests/fixtures",
]


## Every script under root, skipping vendored code and deliberately broken fixtures.
static func scripts_under(root: String) -> PackedStringArray:
	var scripts: PackedStringArray = []
	if SKIPPED_FOLDERS.has(root):
		return scripts
	for file: String in DirAccess.get_files_at(root):
		if file.get_extension() == "gd":
			scripts.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		scripts.append_array(scripts_under(root.path_join(directory)))
	return scripts


static func compiles(path: String) -> bool:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	var script: GDScript = resource as GDScript
	return script != null and script.can_instantiate()

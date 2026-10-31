class_name LayerCheck
extends RefCounted
## Scans a folder for violations of the core layer rules.

const ALLOWED_PREFIXES: PackedStringArray = ["res://core/", "res://data/"]
const ALLOWED_SINGLETONS: PackedStringArray = ["Geometry2D", "Geometry3D"]
const FORBIDDEN_WORDS: PackedStringArray = [
	"load",
	"get_tree",
	"get_node",
	"get_node_or_null",
	"get_main_loop",
	"get_singleton",
	"FileAccess",
	"DirAccess",
	"ResourceLoader",
	"ResourceSaver",
	"HTTPRequest",
	"HTTPClient",
]
const RESOURCE_EXTENSIONS: PackedStringArray = ["gd", "tres", "res", "tscn", "scn", "gdshader"]
const SCENE_EXTENSIONS: PackedStringArray = ["tscn", "scn"]


## Returns one "path:line: reason" entry per violation. A missing root is a violation.
static func scan(root: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(root):
		return PackedStringArray(["%s: folder not found" % root])

	var forbidden: RegEx = RegEx.create_from_string("\\b(%s)\\b" % "|".join(_forbidden_names()))
	var problems: PackedStringArray = []
	for path: String in _files_under(root):
		if path.get_extension() == "gd":
			problems.append_array(_check_script(path, forbidden))
		elif SCENE_EXTENSIONS.has(path.get_extension()):
			problems.append("%s: scene in core" % path)
	return problems


static func _forbidden_names() -> PackedStringArray:
	var names: PackedStringArray = FORBIDDEN_WORDS.duplicate()
	for singleton: String in Engine.get_singleton_list():
		if not ALLOWED_SINGLETONS.has(singleton):
			names.append(singleton)
	for setting: Dictionary in ProjectSettings.get_property_list():
		var key: String = setting["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = global_class["path"]
		if not _is_allowed_path(path):
			names.append(global_class["class"])
	return names


static func _check_script(path: String, forbidden: RegEx) -> PackedStringArray:
	var problems: PackedStringArray = []
	if not FileAccess.file_exists(path):
		return PackedStringArray(["%s: cannot read" % path])

	var line_number: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_number += 1
		var parts: PackedStringArray = _split_line(line)
		for found: RegExMatch in forbidden.search_all(parts[0]):
			problems.append("%s:%d: forbidden name: %s" % [path, line_number, found.get_string()])
		for text: String in parts.slice(1):
			var reason: String = _check_string(text)
			if not reason.is_empty():
				problems.append("%s:%d: %s" % [path, line_number, reason])

	for reason: String in _check_inheritance(path):
		problems.append("%s: %s" % [path, reason])
	return problems


## Returns the line's code first, then each string literal, with comments removed.
static func _split_line(line: String) -> PackedStringArray:
	var code: String = ""
	var text: String = ""
	var quote: String = ""
	var strings: PackedStringArray = []
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if quote.is_empty():
			if character == "#":
				break
			if character == '"' or character == "'":
				quote = character
				text = ""
			else:
				code += character
		elif character == "\\":
			index += 1
		elif character == quote:
			strings.append(text)
			quote = ""
		else:
			text += character
		index += 1

	var parts: PackedStringArray = [code]
	parts.append_array(strings)
	return parts


static func _check_string(text: String) -> String:
	if text.begins_with("uid://"):
		return "uid reference: " + text
	if text.begins_with("res://"):
		if not _is_allowed_path(text.simplify_path()):
			return "reference outside core and data: " + text
		return ""
	if RESOURCE_EXTENSIONS.has(text.get_extension()):
		return "relative path: " + text
	return ""


static func _check_inheritance(path: String) -> PackedStringArray:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	var script: GDScript = resource as GDScript
	if script == null or not script.can_instantiate():
		return PackedStringArray(["does not compile"])

	var reasons: PackedStringArray = []
	if ClassDB.is_parent_class(script.get_instance_base_type(), "Node"):
		reasons.append("Node subclass: " + script.get_instance_base_type())
	for value: Variant in script.get_script_constant_map().values():
		if value is GDScript:
			var inner: GDScript = value
			if ClassDB.is_parent_class(inner.get_instance_base_type(), "Node"):
				reasons.append("Node subclass: " + inner.get_instance_base_type())
	return reasons


static func _is_allowed_path(path: String) -> bool:
	for prefix: String in ALLOWED_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


static func _files_under(root: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for file: String in DirAccess.get_files_at(root):
		files.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		files.append_array(_files_under(root.path_join(directory)))
	return files

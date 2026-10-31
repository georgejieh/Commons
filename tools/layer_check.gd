class_name LayerCheck
extends RefCounted
## Scans scripts under a root for violations of the core layer rules.

const ALLOWED_PREFIXES: PackedStringArray = ["res://core/", "res://data/"]


## Returns one "path:line: reason" entry per violation.
static func scan(root: String, autoloads: PackedStringArray) -> PackedStringArray:
	var problems: PackedStringArray = []
	for path: String in _scripts_under(root):
		var line_number: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			line_number += 1
			var code: String = line.get_slice("#", 0)
			for reason: String in _check_line(code, autoloads):
				problems.append("%s:%d: %s" % [path, line_number, reason])
	return problems


## Names of the autoloads declared in project settings.
static func declared_autoloads() -> PackedStringArray:
	var names: PackedStringArray = []
	for setting: Dictionary in ProjectSettings.get_property_list():
		var key: String = setting["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	return names


static func _check_line(code: String, autoloads: PackedStringArray) -> PackedStringArray:
	var reasons: PackedStringArray = []
	var res_path: RegEx = RegEx.create_from_string("res://[^\"'\\s]*")
	for found: RegExMatch in res_path.search_all(code):
		if not _is_allowed_path(found.get_string()):
			reasons.append("reference outside core and data: " + found.get_string())

	var base: RegEx = RegEx.create_from_string("^\\s*extends\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var base_match: RegExMatch = base.search(code)
	if base_match != null:
		var base_class: String = base_match.get_string(1)
		if ClassDB.is_parent_class(base_class, "Node"):
			reasons.append("Node subclass: " + base_class)

	for autoload_name: String in autoloads:
		var access: RegEx = RegEx.create_from_string("\\b%s\\b" % autoload_name)
		if access.search(code) != null:
			reasons.append("autoload access: " + autoload_name)
	return reasons


static func _is_allowed_path(path: String) -> bool:
	for prefix: String in ALLOWED_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


static func _scripts_under(root: String) -> PackedStringArray:
	var scripts: PackedStringArray = []
	for file: String in DirAccess.get_files_at(root):
		if file.get_extension() == "gd":
			scripts.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		scripts.append_array(_scripts_under(root.path_join(directory)))
	return scripts

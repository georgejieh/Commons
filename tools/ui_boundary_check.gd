class_name UiBoundaryCheck
extends RefCounted
## Scans UI scripts for anything that could change run state without a command:
## the core loop and round types, and the mutators on them. The UI reaches a run only
## through RunController, which hands out copies.

const FORBIDDEN_WORDS: PackedStringArray = [
	"RunLoop",
	"RunRecord",
	"RoundState",
	"RoundAction",
	"ModifierStack",
	"CardModifiers",
	"PlotSwap",
	"RoundBanking",
	"RunMeters",
	"player_bid",
	"player_swap",
	"player_play",
	"player_need",
	"next_set",
	"start_set",
	"resume_at_checkpoint",
	"set_enhancement",
	"set_seal",
	"set_owner_stamp",
]
const EXTENSIONS: PackedStringArray = ["gd", "tscn"]


## Returns one "path:line: word" entry per violation. A missing root is a violation.
static func scan(root: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(root):
		return PackedStringArray(["%s: folder not found" % root])
	var pattern: RegEx = RegEx.create_from_string("\\b(%s)\\b" % "|".join(FORBIDDEN_WORDS))
	var found: PackedStringArray = []
	for path: String in _files(root):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var code: String = lines[index].get_slice("#", 0)
			var hit: RegExMatch = pattern.search(code)
			if hit != null:
				found.append("%s:%d: %s" % [path, index + 1, hit.get_string()])
	return found


static func _files(root: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for name: String in DirAccess.get_files_at(root):
		if name.get_extension() in EXTENSIONS:
			files.append(root.path_join(name))
	for folder: String in DirAccess.get_directories_at(root):
		files.append_array(_files(root.path_join(folder)))
	return files

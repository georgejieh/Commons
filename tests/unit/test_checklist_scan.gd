extends GdUnitTestSuite
## No tracked script, tool, workflow or document cites the checklist, which is a local
## file a fresh clone does not have: an item ID or a phase means nothing to a reader there.
## A comment gives the reason, or the ADR that holds it. The ADRs are history and may name
## the item that prompted them, and add-ons are not the project's own.

const TYPES: Array[String] = ["gd", "py", "sh", "yml", "md"]
const SPARED: Array[String] = ["docs/adr/", "addons/"]
## An item ID as the checklist writes it (a phase, a dot, a number, a letter), or a phase
## in prose or in a name.
const CITATION: String = r"\bP\d+[A-Z]?\.\d+[a-z]?\b|(?<![A-Za-z])[Pp]hase[ _]\d+[A-Za-z]?\b"


func test_no_tracked_file_cites_the_checklist() -> void:
	var files: PackedStringArray = _tracked()
	assert_int(files.size()).is_greater(100)
	var citation: RegEx = RegEx.create_from_string(CITATION)
	var offences: PackedStringArray = []
	for path: String in files:
		offences.append_array(_offences(path, citation))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


func test_an_item_and_a_phase_are_caught_and_an_adr_is_not() -> void:
	var citation: RegEx = RegEx.create_from_string(CITATION)
	# Built from parts, so this file holds no citation of its own.
	for cited: String in [
		"(P" + "4.14)", "P" + "3B.13 voices", "P" + "5.2a", "Phase" + " 4", "_phase" + "_4"
	]:
		assert_object(citation.search(cited)).override_failure_message(cited).is_not_null()
	for plain: String in ["ADR 0030", "PLAN.md", "P2P", "p99 at 4.7", "0016-phase-3b"]:
		assert_object(citation.search(plain)).override_failure_message(plain).is_null()


## The project's own files of the scanned types that git tracks, relative to the root.
func _tracked() -> PackedStringArray:
	var output: Array = []
	var root: String = ProjectSettings.globalize_path("res://")
	# OS.execute has no time limit of its own: tools/test.sh bounds the whole run.
	var status: int = OS.execute("git", ["-C", root, "ls-files"], output)
	assert_int(status).override_failure_message("git ls-files failed").is_equal(0)
	var found: PackedStringArray = []
	for path: String in "".join(PackedStringArray(output)).split("\n", false):
		if TYPES.has(path.get_extension()) and not SPARED.any(path.begins_with):
			found.append(path)
	return found


func _offences(path: String, citation: RegEx) -> PackedStringArray:
	var found: PackedStringArray = []
	var lines: PackedStringArray = FileAccess.get_file_as_string("res://" + path).split("\n")
	for index: int in lines.size():
		if citation.search(lines[index]) != null:
			found.append("%s:%d: %s" % [path, index + 1, lines[index].strip_edges()])
	return found

extends GdUnitTestSuite
## Every public member of core/, game/, ui/ and data/ has a ## doc line of its own directly
## above it (docs/CODE_STANDARD.md): a func, var, const, signal, enum or inner class whose
## name does not start with an underscore, at the top of its script or of an inner class.
## An annotation line, such as @export or @warning_ignore, may stand between the doc and
## the member; a comment above a group documents only the first of it.

## A member line: annotations on the same line, static, then the kind and a public name.
const MEMBER: String = (
	r"^(\t?)(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?"
	+ r"(func|var|const|signal|enum|class)\s+([A-Za-z]\w*)"
)


func test_every_public_member_has_a_doc_line() -> void:
	var scripts: PackedStringArray = SourceScan.files(SourceScan.ROOTS, ["gd"])
	assert_int(scripts.size()).is_greater(300)
	var offences: PackedStringArray = []
	for path: String in scripts:
		offences.append_array(_undocumented(path, SourceScan.read(path)))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


func test_the_scan_catches_a_member_with_no_doc_line_of_its_own() -> void:
	var script: String = (
		"\n"
		. join(
			[
				"class_name Made",
				"extends RefCounted",
				"## A made-up script.",
				"",
				"signal opened",
				"## The first of a group.",
				"const FIRST: int = 1",
				"const SECOND: int = 2",
				"@export var shown: bool = false",
				"## Documented, over its annotation.",
				"@onready var held: int = 0",
				"var _private: int = 0",
				"",
				"",
				"static func make() -> void:",
				"\tvar local: int = 0",
				"",
				"",
				"## An inner record.",
				"class Inner:",
				"\textends RefCounted",
				"\tvar field: int",
			]
		)
	)
	var caught: PackedStringArray = _undocumented("res://made_up.gd", script)
	var names: Array[String] = []
	for offence: String in caught:
		names.append(offence.get_slice(" ", 2))
	assert_array(names).contains_exactly(["opened", "SECOND", "shown", "make", "field"])


## Each public member of the script with no ## line above it, as "path:line kind name".
static func _undocumented(path: String, text: String) -> PackedStringArray:
	var lines: PackedStringArray = text.split("\n")
	var offences: PackedStringArray = []
	var in_class: bool = false
	for index: int in lines.size():
		var line: String = lines[index]
		if not line.is_empty() and not line[0] in [" ", "\t"]:
			in_class = line.begins_with("class ")
		var hit: RegExMatch = SourceScan.pattern(MEMBER).search(line)
		if hit == null or (not hit.get_string(1).is_empty() and not in_class):
			continue
		var above: int = index - 1
		while above >= 0 and lines[above].strip_edges().begins_with("@"):
			above -= 1
		if above < 0 or not lines[above].strip_edges().begins_with("##"):
			offences.append("%s:%d %s %s" % [path, index + 1, hit.get_string(2), hit.get_string(3)])
	return offences

extends GdUnitTestSuite
## Scans the tests and the tools for the ways a test can pass on nothing, or pass only
## when the machine is quick enough. The fixtures of the layer check are left out: they
## break the rules on purpose.

const FIXTURES: String = "res://tests/fixtures/"
## A private member reached by its name in a string, which a rename leaves reading null.
const NAMED_REACH: String = r'\.(?:get|set|call|callv|call_deferred|set_deferred)\(\s*&?"_'
## Another object's member read or called by its private name.
const PRIVATE_ACCESS: String = r"([\w)\]]+)\._([A-Za-z]\w*)"
## The engine's frame steps, which a test may call to step time by hand.
const STEPS: Array[String] = ["process", "physics_process"]
## The comment that must stand on the line above a frame step called by hand.
const STEPPED: String = "# Stepped:"
## A wait for a fixed time of the wall clock.
const WALL_CLOCK: String = r"\b(?:create_timer|await_millis|OS\.delay_(?:msec|usec))\("
## The comment that must stand on the line above a wait for a fixed time.
const TIMED: String = "# Timed:"


## A test or a tool reaches what it checks by a typed name, never a private member by its
## string: a rename compiles and the string then reads null, so the test may pass on
## nothing. A test does not touch another object's private member either, but for its
## _process or _physics_process, which it may call to step time by hand when the line
## above opens with "# Stepped:" and says so.
func test_no_test_or_tool_reaches_a_private_member() -> void:
	var offences: PackedStringArray = []
	for path: String in _scripts(["res://tests", "res://tools"]):
		var code: PackedStringArray = SourceScan.code_of(SourceScan.read(path)).split("\n")
		var text: PackedStringArray = SourceScan.read(path).split("\n")
		for index: int in code.size():
			var line: String = code[index]
			if SourceScan.pattern(NAMED_REACH).search(line) != null:
				offences.append(_offence(path, index, line))
			if not path.begins_with("res://tests"):
				continue
			for hit: RegExMatch in SourceScan.pattern(PRIVATE_ACCESS).search_all(line):
				if hit.get_string(1) in ["self", "super"]:
					continue
				if STEPS.has(hit.get_string(2)) and _above(text, index).begins_with(STEPPED):
					continue
				offences.append(_offence(path, index, line))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


## A test waits for what it set off, through TestWait, never for a fixed time: a sleep is
## slow when the thing came early and flaky when it came late. A wait for a fixed time is
## kept only where the time itself is the subject, such as a thing that must not happen
## within it, under a line that opens with "# Timed:" and says so.
func test_no_test_waits_a_fixed_time_unless_the_time_is_the_subject() -> void:
	var offences: PackedStringArray = []
	for path: String in _scripts(["res://tests"]):
		var code: PackedStringArray = SourceScan.code_of(SourceScan.read(path)).split("\n")
		var text: PackedStringArray = SourceScan.read(path).split("\n")
		for index: int in code.size():
			var line: String = code[index]
			var timed: bool = _above(text, index).begins_with(TIMED)
			if SourceScan.pattern(WALL_CLOCK).search(line) != null and not timed:
				offences.append(_offence(path, index, line))
	assert_array(offences).override_failure_message("\n".join(offences)).is_empty()


## Every script under roots but the layer check's fixtures.
func _scripts(roots: Array[String]) -> PackedStringArray:
	var kept: PackedStringArray = []
	for path: String in SourceScan.files(roots, ["gd"]):
		if not path.begins_with(FIXTURES):
			kept.append(path)
	return kept


## The line above index, as written, without its indent.
func _above(text: PackedStringArray, index: int) -> String:
	return text[index - 1].strip_edges() if index > 0 else ""


func _offence(path: String, index: int, line: String) -> String:
	return "%s:%d %s" % [path, index + 1, line.strip_edges()]

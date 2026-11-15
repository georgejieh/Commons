extends GdUnitTestSuite
## Tools run with `godot --script` are compiled before the autoloads exist. A class named
## in one can drag in scripts that use Settings or Strings, and the tool then fails to
## compile. The test suite never sees that, because autoloads exist while it runs, so
## each tool is compiled here the way the cloud run compiles it. A tool that fails must
## reach that node as Object or Node, not by its class name.

const TOOLS: PackedStringArray = [
	"res://tools/playtest.gd",
	"res://tools/board_states.gd",
	"res://tools/texture_budget.gd",
]
## What Godot prints for a tool that does not compile: a compile error, or a parse error
## such as a warning treated as one.
const FAILURES: Array[String] = ["Compile Error", "Parse Error"]


func test_script_tools_compile_without_autoloads() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	for tool_path: String in TOOLS:
		var output: Array = []
		var arguments: PackedStringArray = [
			"--headless", "--path", project, "--check-only", "--script", tool_path
		]
		OS.execute(OS.get_executable_path(), arguments, output, true)
		var text: String = "\n".join(PackedStringArray(output))
		(
			assert_bool(FAILURES.any(func(failure: String) -> bool: return text.contains(failure)))
			. override_failure_message("%s does not compile on its own:\n%s" % [tool_path, text])
			. is_false()
		)

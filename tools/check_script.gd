extends SceneTree
## Exits 1 if the script --check names does not compile, 2 without --check. Tests use it
## to prove the compile gate fails, in a process where a broken script can't fail them.

const USAGE: String = "check_script.gd -- --check PATH"


func _initialize() -> void:
	var options: ToolOptions = ToolOptions.new(USAGE)
	if options.text("check").is_empty():
		options.refuse("Needs --check PATH.")
	if options.failed():
		quit(2)
		return
	quit(0 if ScriptCheck.compiles(options.text("check")) else 1)

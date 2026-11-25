extends RefCounted
## Where a playtest tool keeps its saves under user://. Two tools running at once must
## not share a folder, or each overwrites the other's run save and both fail: --profile
## NAME gives a run its own (user://playtest_NAME/). Without it the folder is the tool's
## usual one. Loaded at run time by path, like the other tools.
## Development only; tools/ never ships.

const FLAG: String = "--profile"


## The folder for a tool whose usual folder is user://base/, with its trailing slash.
static func folder(base: String, args: PackedStringArray) -> String:
	var at: int = args.find(FLAG)
	if at < 0 or at + 1 >= args.size():
		return "user://%s/" % base
	return "user://%s_%s/" % [base, args[at + 1].validate_filename()]


## Points the Saves autoload at a run save, with its profile beside it, in the tool's own
## folder under the sandbox (user://tools/base/), and returns the folder. For a tool that
## plays a run in the app, so two such tools at once never share one.
static func keep_run(root: Node, base: String, args: PackedStringArray) -> String:
	var kept: String = folder("tools/" + base, args)
	root.get_node("Saves").call("use_run_path", kept + "run.json")
	return kept

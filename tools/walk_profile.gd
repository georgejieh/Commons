class_name WalkProfile
extends RefCounted
## Where a tool that plays a run keeps its saves and its settings: a folder of its own
## under the sandbox (SavePaths.SANDBOX, ADR 0037), user://tools/BASE/, so no tool can
## reach the player's files. Two tools running at once must not share a folder, or each
## overwrites the other's run save and both fail: --profile NAME gives a run its own
## (user://tools/BASE_NAME/). Development only; tools/ never ships.

const FLAG: String = "profile"
const RUN_FILE: String = "run.json"


## The folder for a tool whose usual folder is user://tools/base/, with its trailing slash.
static func folder(base: String, options: ToolOptions) -> String:
	var name: String = options.text(FLAG)
	var leaf: String = base if name.is_empty() else "%s_%s" % [base, name.validate_filename()]
	return SavePaths.SANDBOX.path_join(leaf) + "/"


## Points the Saves autoload at a run save, with its profile beside it, in the tool's own
## folder, and returns the folder. For a tool that plays a run in the app.
static func keep_run(root: Node, base: String, options: ToolOptions) -> String:
	var kept: String = folder(base, options)
	root.get_node("Saves").call("use_run_path", kept + RUN_FILE)
	return kept

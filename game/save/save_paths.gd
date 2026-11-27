class_name SavePaths
extends RefCounted
## Where the player's files are (ADR 0037). Only a launch of the game itself keeps them
## at their own paths. A tree run by a script, as every tool, the playtest and the test
## run are, keeps its defaults under SANDBOX instead, so nothing but the game can ever
## read or write the player's run save, backup, ledger, profile or settings. A path a tool
## or test names for itself is used as it is.

## The folder a script's tree keeps its default files under, so the player's are never touched.
const SANDBOX: String = "user://tools"


## True for the game itself: the engine runs its tree with no script of a tool's.
static func normal_launch(tree: SceneTree) -> bool:
	return tree != null and tree.get_script() == null


## The default path as a run of this kind keeps it: as it is for the game, under the
## sandbox for anything else.
static func of(path: String, normal: bool) -> String:
	return path if normal else SANDBOX.path_join(path.trim_prefix("user://"))

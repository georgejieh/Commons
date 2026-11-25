extends Node
## The Saves autoload: the run save service and the profile save.
## Both only write and read files; the run lives in RunController, so nothing here holds
## run state.

var _run: SaveService = null
var _profile: SaveService = null


## The defaults are chosen once the tree is known: a tool's or a test's are in the sandbox.
func _enter_tree() -> void:
	use_default_paths()


func run_service() -> SaveService:
	return _run


func profile_service() -> SaveService:
	return _profile


## The game's own files on a launch of the game, the sandbox's otherwise (SavePaths).
func use_default_paths() -> void:
	var normal: bool = SavePaths.normal_launch(get_tree())
	_run = SaveService.for_run(SavePaths.of(SaveService.RUN_PATH, normal))
	_profile = Profile.service(SavePaths.of(SaveService.PROFILE_PATH, normal))


## Points the run save at another file, for tests, and the profile at one beside it, so
## a test that keeps its run apart never writes the player's real profile.
func use_run_path(path: String) -> void:
	_run = SaveService.for_run(path)
	_profile = Profile.service(path.get_basename() + "_profile.json")

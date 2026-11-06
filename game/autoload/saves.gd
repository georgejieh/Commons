class_name SaveHub
extends Node
## The Saves autoload: the run save service (P3A.6) and the profile save (P4.6).
## Both only write and read files; the run lives in RunController, so nothing here holds
## run state.

var _run: SaveService = SaveService.for_run()
var _profile: SaveService = Profile.service()


func run_service() -> SaveService:
	return _run


func profile_service() -> SaveService:
	return _profile


## Points the profile save at another file, for tests.
func use_profile_path(path: String) -> void:
	_profile = Profile.service(path)


## Points the run save at another file, for tests, and the profile at one beside it, so
## a test that keeps its run apart never writes the player's real profile.
func use_run_path(path: String) -> void:
	_run = SaveService.for_run(path)
	_profile = Profile.service(path.get_basename() + "_profile.json")

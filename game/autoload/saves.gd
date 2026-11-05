class_name SaveHub
extends Node
## The Saves autoload: the run save service (P3A.6). It writes and reads files only; the
## run itself lives in RunController, so nothing here holds run state.

var _run: SaveService = SaveService.for_run()


func run_service() -> SaveService:
	return _run


## Points the run save at another file, for tests.
func use_run_path(path: String) -> void:
	_run = SaveService.for_run(path)

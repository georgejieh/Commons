extends Node
## Fixture: a UI script that takes the run's loop on a line where a string with a hash in
## it, as a colour is written, comes first.


func _tinted(controller: RunController) -> Array:
	return [Color("#c8102e"), controller.run_loop()]

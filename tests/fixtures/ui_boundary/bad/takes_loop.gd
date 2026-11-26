extends Node
## Fixture: a UI script that takes the run's loop from the controller.


func _loop(controller: RunController) -> Object:
	return controller.run_loop()

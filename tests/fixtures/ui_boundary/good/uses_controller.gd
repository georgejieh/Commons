extends Node
## Fixture: a UI script that goes through the controller. Comments may name RunLoop.


func _act(controller: RunController) -> void:
	controller.pass_turn()

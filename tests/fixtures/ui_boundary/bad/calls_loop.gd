extends Node
## Fixture: a UI script that reaches past the controller.


func _act(loop: Object) -> void:
	loop.call("player_play", [])

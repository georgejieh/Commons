extends SceneTree
## Fails if core/ breaks the layer rules. Run:
##   godot --headless --path . --script res://tools/check_layers.gd


func _initialize() -> void:
	var problems: PackedStringArray = LayerCheck.scan("res://core")
	for problem: String in problems:
		printerr(problem)
	print("Layer check: %d problem(s)" % problems.size())
	quit(1 if problems.size() > 0 else 0)

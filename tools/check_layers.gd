extends SceneTree
## Fails if core/ breaks the layer rules. Run:
##   godot --headless --path . --script res://tools/check_layers.gd
## Optional user args after `--`: a root to scan, then extra autoload names.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var root: String = args[0] if args.size() > 0 else "res://core"
	var autoloads: PackedStringArray = LayerCheck.declared_autoloads()
	autoloads.append_array(args.slice(1))

	var problems: PackedStringArray = LayerCheck.scan(root, autoloads)
	for problem: String in problems:
		printerr(problem)
	print("Layer check: %d problem(s) in %s" % [problems.size(), root])
	quit(1 if problems.size() > 0 else 0)

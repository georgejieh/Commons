extends SceneTree
## Renders the table in each of the Plan's seven board states (P3B.12), the last
## corruption stage, and the clean board at every stage, and saves one screenshot per
## state for checking by eye. Needs a
## real window, not --headless:
##   godot --path . --script res://tools/board_states.gd -- --out reports/board_states
## Development only; tools/ never ships.

const SEED: int = 4242
const SETTLE_FRAMES: int = 40
const LAST_STAGE: int = 9

var _out: String = "res://reports/board_states"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--out")
	if at >= 0 and at + 1 < args.size():
		_out = "res://" + args[at + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	app.call("new_run", SEED)
	var table: Node = app.call("show_screen", "table", true)
	await _settle()
	var dread: Node = table.get("_dread")
	var states: Dictionary = load("res://game/horror/board_state.gd").get("BOARD_STATES")
	for state: String in states:
		var inputs: Vector3 = states[state]
		dread.call("force", int(inputs.x), int(inputs.y), inputs.z > 0.0, 0)
		await _settle()
		await _shot(state)
	dread.call("force", 10, 10, false, LAST_STAGE)
	await _settle()
	await _shot("corruption_stage_%d" % LAST_STAGE)
	# The clean board at every corruption stage, to check the stage art by eye.
	for stage: int in LAST_STAGE + 1:
		dread.call("force", 0, 0, false, stage)
		await _settle()
		await _shot("clean_stage_%d" % stage)
	quit(0)


func _settle() -> void:
	for _frame: int in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, name])
	print("saved %s" % name)

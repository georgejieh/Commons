extends SceneTree
## Saves one screenshot of the 2D table mid-round, after the player has bid and a few
## plays are down, for checking motion and layout by eye. Needs a real window:
##   godot --path . --script res://tools/table_moment.gd -- --out reports/shots
## Development only; tools/ never ships.

const SEED: int = 4242
const PLAYER_TURNS: int = 3
const SETTLE_FRAMES: int = 25

var _out: String = "res://reports/shots"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--out")
	if at >= 0 and at + 1 < args.size():
		_out = "res://" + args[at + 1]
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	app.call("new_run", SEED)
	var table: Node = app.call("show_screen", "table", true)
	var controller: Node = app.get("controller")
	var script: GDScript = load("res://tests/unit/controller_script.gd")
	var driver: Object = script.new()
	var turns: int = 0
	while turns < PLAYER_TURNS:
		await process_frame
		var events: Node = table.get("_player")
		if not events.call("is_idle"):
			continue
		if driver.call("act", controller):
			turns += 1
	for _frame: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out.path_join("table_mid_round.png")))
	print("saved table_mid_round")
	quit(0)

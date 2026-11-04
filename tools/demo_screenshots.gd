extends SceneTree
## Opens the demo, starts a seeded run and saves a screenshot of each screen, for
## checking layout by eye. Needs a real window, not --headless:
##   godot --path . --script res://tools/demo_screenshots.gd -- --out reports/shots
## Development only; tools/ never ships.

const SEED: int = 4242
const SCREENS: Array[String] = [
	"title", "set_intro", "table", "store", "set_summary", "settings", "demo_complete"
]
const SETTLE_FRAMES: int = 70

var _out: String = "res://reports/shots"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--out")
	if at >= 0 and at + 1 < args.size():
		_out = "res://" + args[at + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see when
	# it compiles.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	await _settle()
	await _shot("title")
	app.call("new_run", SEED)
	for screen_id: String in SCREENS.slice(1):
		if screen_id == "store":
			_finish_set(app)
		app.call("show_screen", screen_id, true)
		await _settle()
		await _shot(screen_id)
	quit(0)


## Plays the first Set by bot so the store and summary have something to show.
func _finish_set(app: Node) -> void:
	var controller: Node = app.get("controller")
	var script: GDScript = load("res://tests/unit/controller_script.gd")
	var driver: Object = script.new()
	while driver.call("act", controller):
		pass
	controller.call("finish_set")


func _settle() -> void:
	for _frame: int in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))
	print("saved ", name)

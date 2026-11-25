extends SceneTree
## Opens the demo, starts a seeded run and saves a screenshot of each screen, for
## checking layout by eye. Needs a real window for its pictures:
##   godot --path . --script res://tools/demo_screenshots.gd -- --out reports/shots
## Add --text-size N (0 Standard, 1 Large, 2 Largest; ADR 0034) to shoot at a text size,
## and --grayscale or --reduced-motion (ADR 0035, tools/display_flags.gd) for a grayscale
## pass over every frame or reduced motion. They are set for this run only and never
## reach the player's settings file. Run with --headless it names each frame without
## saving it. Over the title it also shoots ADR 0037's two notices, which only a real
## launch shows: "already open" and, for a session that did not close, where its files
## were kept. Development only; tools/ never ships.

const SEED: int = 4242
const SCREENS: Array[String] = [
	"title", "set_intro", "table", "store", "set_summary", "settings", "controls", "demo_complete"
]
const SETTLE_FRAMES: int = 110
const NOTICE: String = "res://ui/screens/session_notice.gd"
const GATE: String = "res://ui/launch_gate.gd"
const SESSION: String = "res://data/session/session_params.tres"
## A folder named as the game names one.
const KEPT: String = "user://crashes/2026-11-24T21.07.45"

var _out: String = "res://reports/shots"
var _args: PackedStringArray = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--out")
	if at >= 0 and at + 1 < args.size():
		_out = "res://" + args[at + 1]
	_args = args
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see when
	# it compiles.
	var flags: GDScript = load("res://tools/display_flags.gd")
	print(flags.call("apply", root, _args))
	# Standard unless a size was asked for, whatever the player's file says.
	if int(flags.call("text_size", _args)) < 0:
		root.get_node("Settings").call("set_value", "text_size", 0)
	# A run save of its own, in the sandbox, never the player's (tools/walk_profile.gd).
	load("res://tools/walk_profile.gd").call(
		"keep_run", root, "demo_screenshots", OS.get_cmdline_user_args()
	)
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	await _settle()
	await _shot("title")
	await _notices(app)
	app.call("new_run", SEED)
	for screen_id: String in SCREENS.slice(1):
		if screen_id == "store":
			_finish_set(app)
		app.call("show_screen", screen_id, true)
		await _settle()
		await _shot(screen_id)
	quit(0)


## The "already open" notice over the title, then the title as it opens after a session
## that did not close.
func _notices(app: Node) -> void:
	var notices: GDScript = load(NOTICE)
	var seconds: int = load(GATE).call("wait_seconds", load(SESSION))
	var none: Callable = func() -> void: pass
	var open: Control = notices.call("already_open", seconds, none, none)
	app.add_child(open)
	await _settle()
	await _shot("notice_already_open")
	open.free()
	app.set("kept_crash", KEPT)
	app.call("show_screen", "title", true)
	await _settle()
	await _shot("notice_kept")


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
	if DisplayServer.get_name() == "headless":
		print("frame ", name)
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))
	print("saved ", name)

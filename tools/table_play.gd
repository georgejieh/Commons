class_name TablePlay
extends RefCounted
## Opens the app's 2D table in the running window and plays a Set at it by bot at the
## table's real pacing, recording every frame's time and the scene's node count while a
## round is in play. Shared by tools/table_perf.gd and tools/perf_budget.gd. Needs a real
## window, not --headless. The app and the controller are reached by name at run time,
## because a --script tool compiles before the autoloads exist.

const WARMUP_FRAMES: int = 30
const USEC_PER_MSEC: float = 1000.0

## Milliseconds each frame took, and the node count at each frame inside a round.
var frame_ms: PackedFloat64Array = []
var node_counts: PackedInt64Array = []
## The app and its table screen, once open.
var app: Node = null
var table: Node = null


## Loads the app, lets start begin the run on it (it takes the app), then shows the table.
## The run saves in the tool's own sandbox folder (WalkProfile), as options name it.
func open(tree: SceneTree, start: Callable, options: ToolOptions) -> Node:
	WalkProfile.keep_run(tree.root, "table_play", options)
	var scene: PackedScene = load("res://ui/main.tscn")
	app = scene.instantiate()
	tree.root.add_child(app)
	start.call(app)
	table = app.call("show_screen", "table", true)
	return table


## Lets the table settle for a few frames before anything is timed.
func warm_up(tree: SceneTree) -> void:
	for _frame: int in WARMUP_FRAMES:
		await tree.process_frame


## Plays by bot for the given seconds, or until the table is gone. on_frame, when valid,
## is called after each frame is timed. With act false the table is left to itself.
func play_set(tree: SceneTree, seconds: float, on_frame: Callable, act: bool) -> void:
	var controller: Node = app.get("controller")
	var script: GDScript = load("res://tests/unit/controller_script.gd")
	var driver: Object = script.new()
	var started: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		frame_ms.append((now - last) / USEC_PER_MSEC)
		last = now
		if on_frame.is_valid():
			on_frame.call()
		var in_round: bool = WalkBase.view(controller, "table").call("seat_view") != null
		if in_round:
			node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if not is_instance_valid(table) or table.get_parent() == null:
			break
		var events: Node = WalkBase.member(table, "_player")
		if events.call("is_idle") and act:
			driver.call("act", controller)

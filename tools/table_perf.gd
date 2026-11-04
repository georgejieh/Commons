extends SceneTree
## Measures the 2D table on this machine (P3B.3, ADR 0016): plays a Set by bot at the
## table's real pacing, and reports the frame times and whether any node was made
## while a round was in play. Needs a real window, not --headless:
##   godot --path . --script res://tools/table_perf.gd -- --seconds 40
## Prints one result line per measure. Development only; tools/ never ships.

const SEED: int = 5151
const WARMUP_FRAMES: int = 30

var _seconds: float = 40.0
var _frame_ms: PackedFloat64Array = []
var _node_counts: PackedInt64Array = []
var _rounds_counted: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--seconds")
	if at >= 0 and at + 1 < args.size():
		_seconds = float(args[at + 1])
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see when
	# it compiles.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	app.call("new_run", SEED)
	var table: Node = app.call("show_screen", "table", true)
	for _frame: int in WARMUP_FRAMES:
		await process_frame
	var controller: Node = app.get("controller")
	var script: GDScript = load("res://tests/unit/controller_script.gd")
	var driver: Object = script.new()
	var started: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < int(_seconds * 1000.0):
		await process_frame
		var now: int = Time.get_ticks_usec()
		_frame_ms.append((now - last) / 1000.0)
		last = now
		var in_round: bool = controller.call("seat_view") != null
		if in_round:
			_node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if not is_instance_valid(table) or table.get_parent() == null:
			break
		var events: Node = table.get("_player")
		if events.call("is_idle"):
			driver.call("act", controller)
	_report()
	quit(0)


func _report() -> void:
	var sorted: PackedFloat64Array = _frame_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var count: int = sorted.size()
	print("frames=%d" % count)
	print("mean_ms=%.2f" % (total / maxi(1, count)))
	print("median_ms=%.2f" % sorted[count / 2])
	print("p99_ms=%.2f" % sorted[mini(count - 1, int(count * 0.99))])
	print("mean_fps=%.1f" % (1000.0 * count / maxf(1.0, total)))
	var counts: PackedInt64Array = _node_counts.duplicate()
	counts.sort()
	if counts.is_empty():
		print("nodes_during_rounds=none sampled")
	else:
		print("nodes_during_rounds_min=%d max=%d" % [counts[0], counts[-1]])

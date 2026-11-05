extends SceneTree
## Measures the 2D table on this machine (P3B.3, ADR 0016): plays a Set by bot at the
## table's real pacing, and reports the frame times and whether any node was made
## while a round was in play. Needs a real window, not --headless:
##   godot --path . --script res://tools/table_perf.gd -- --seconds 40
## With --stress it instead shows all 54 cards at once, moving every frame, from the
## table's own pool, and reports the same measures.
## Prints one result line per measure. Development only; tools/ never ships.

const SEED: int = 5151
const WARMUP_FRAMES: int = 30
const DECK_SIZE: int = 54
const STRESS_COLUMNS: int = 18
const STRESS_ORIGIN: Vector2 = Vector2(120, 140)
const STRESS_STEP: Vector2 = Vector2(92, 200)
const STRESS_SWAY: float = 12.0

var _seconds: float = 40.0
var _frame_ms: PackedFloat64Array = []
var _node_counts: PackedInt64Array = []
var _stress: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--seconds")
	if at >= 0 and at + 1 < args.size():
		_seconds = float(args[at + 1])
	_stress = args.has("--stress")
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
	if _stress:
		await _run_stress(table)
		_report()
		quit(0)
		return
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


## Binds every deck card to a free pooled view on top of the table and sways them all.
func _run_stress(table: Node) -> void:
	var pool: CardPool = table.get("_pool")
	var parent: Control = Control.new()
	table.add_child(parent)
	var views: Array[CardView] = []
	for deck_id: int in DECK_SIZE:
		var view: CardView = pool.acquire()
		if view == null:
			push_error("the pool ran out at card %d" % deck_id)
			return
		view.reparent(parent, false)
		view.bind(CardInstance.from_deck_id(deck_id))
		views.append(view)
	print("visible_cards=%d pool_size=%d" % [views.size(), pool.size()])
	var started: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < int(_seconds * 1000.0):
		var phase: float = Time.get_ticks_msec() / 1000.0
		for index: int in views.size():
			var cell: Vector2 = Vector2(index % STRESS_COLUMNS, index / STRESS_COLUMNS)
			var sway: Vector2 = Vector2(sin(phase + index), cos(phase + index)) * STRESS_SWAY
			views[index].position = STRESS_ORIGIN + cell * STRESS_STEP + sway
		await process_frame
		var now: int = Time.get_ticks_usec()
		_frame_ms.append((now - last) / 1000.0)
		last = now
		_node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


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

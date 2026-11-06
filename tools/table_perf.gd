extends SceneTree
## Measures the 2D table on this machine (P3B.3, ADR 0016): plays a Set by bot at the
## table's real pacing, and reports the frame times and whether any node was made
## while a round was in play. Needs a real window, not --headless:
##   godot --path . --script res://tools/table_perf.gd -- --seconds 40
## With --stress it instead shows all 54 cards at once, moving every frame, from the
## table's own pool, and reports the same measures. With --post-ab it also times the GPU
## per frame, switching the post-process pass on and off every POST_BLOCK frames, and
## reports the pass's cost as the difference (P3B.7). --horror-ab does the same with
## horror intensity at 0 and 1, the table held still at its worst board state, both
## meters high and the last corruption stage (P3B.12). --light-ab switches the table's
## 2D light, which lights the normal-mapped table and cards (P3C.6).
## Prints one result line per measure. Development only; tools/ never ships.

const SEED: int = 5151
const WARMUP_FRAMES: int = 30
const DECK_SIZE: int = 54
const STRESS_COLUMNS: int = 18
const STRESS_ORIGIN: Vector2 = Vector2(120, 140)
const STRESS_STEP: Vector2 = Vector2(92, 200)
const STRESS_SWAY: float = 12.0
const POST_BLOCK: int = 60
## Frames skipped after each switch, while the change settles.
const POST_SETTLE: int = 5

var _seconds: float = 40.0
var _frame_ms: PackedFloat64Array = []
var _node_counts: PackedInt64Array = []
var _stress: bool = false
var _post_ab: bool = false
## The setting the A/B run switches: post_process, or horror_intensity.
var _ab_key: String = "post_process"
var _gpu_on: PackedFloat64Array = []
var _gpu_off: PackedFloat64Array = []
var _post_frame: int = 0
## The table light, for --light-ab.
var _light: PointLight2D = null


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--seconds")
	if at >= 0 and at + 1 < args.size():
		_seconds = float(args[at + 1])
	_stress = args.has("--stress")
	_post_ab = args.has("--post-ab") or args.has("--horror-ab") or args.has("--light-ab")
	if args.has("--horror-ab"):
		_ab_key = "horror_intensity"
	if args.has("--light-ab"):
		_ab_key = "table_light"
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see when
	# it compiles.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	app.call("new_run", SEED)
	var table: Node = app.call("show_screen", "table", true)
	if _ab_key == "table_light":
		var atmosphere: Node = table.get("_atmosphere")
		_light = atmosphere.call("light")
	if _post_ab:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for _frame: int in WARMUP_FRAMES:
		await process_frame
	if _stress:
		await _run_stress(table)
		_report()
		quit(0)
		return
	var horror: bool = _ab_key == "horror_intensity"
	if horror:
		var dread: Object = table.get("_dread")
		dread.call("force", 90, 90, false, 9)
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
		_sample_post()
		var in_round: bool = controller.call("seat_view") != null
		if in_round:
			_node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if not is_instance_valid(table) or table.get_parent() == null:
			break
		var events: Node = table.get("_player")
		if events.call("is_idle") and not horror:
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
		_sample_post()
		_node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


## Times the GPU for this frame against whether the pass was on, then switches the pass
## at each block's end.
func _sample_post() -> void:
	if not _post_ab:
		return
	_post_frame += 1
	var in_block: int = _post_frame % POST_BLOCK
	if in_block >= POST_SETTLE:
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(
			root.get_viewport_rid()
		)
		if _post_on():
			_gpu_on.append(gpu)
		else:
			_gpu_off.append(gpu)
	if in_block == 0:
		_set_post(not _post_on())


func _report_post() -> void:
	if not _post_ab:
		return
	_set_post(true)
	var on: float = _median(_gpu_on)
	var off: float = _median(_gpu_off)
	print("gpu_samples_on=%d off=%d" % [_gpu_on.size(), _gpu_off.size()])
	print("gpu_median_ms_on=%.3f off=%.3f" % [on, off])
	print("%s_gpu_ms=%.3f" % [_ab_key, on - off])


# The Settings autoload is looked up at run time; a --script tool can't name it.
func _post_on() -> bool:
	if _light != null:
		return _light.enabled
	return float(root.get_node("Settings").call("value", _ab_key)) > 0.5


func _set_post(on: bool) -> void:
	if _light != null:
		_light.enabled = on
		return
	var value: Variant = on if _ab_key == "post_process" else (1.0 if on else 0.0)
	root.get_node("Settings").call("set_value", _ab_key, value)


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _report() -> void:
	var sorted: PackedFloat64Array = _frame_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var count: int = sorted.size()
	_report_post()
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

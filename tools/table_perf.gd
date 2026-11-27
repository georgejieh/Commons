extends SceneTree
## Measures the 2D table on this machine (ADR 0016): plays a Set by bot at the table's
## real pacing, and reports the frame times and whether any node was made while a round
## was in play. Needs a real window, not --headless:
##   godot --path . --script res://tools/table_perf.gd -- --seconds 40
## With --stress it instead shows the whole deck at once, moving every frame, from the
## table's own pool, and reports the same measures. With --post-ab it also times the GPU
## per frame, switching the post-process pass on and off every AB_BLOCK frames, and
## reports the pass's cost as the difference. --horror-ab does the same with horror
## intensity at 0 and 1, the table held still at its worst board state, both meters high
## and the last corruption stage. --light-ab switches the table's 2D light, which lights
## the normal-mapped table and cards.
## Prints one result line per measure. Development only; tools/ never ships.

const USAGE: String = "table_perf.gd -- [--seconds S] [--stress|--post-ab|--horror-ab|--light-ab]"
const SEED: int = 5151
const STRESS_COLUMNS: int = 18
const STRESS_ORIGIN: Vector2 = Vector2(120, 140)
const STRESS_STEP: Vector2 = Vector2(92, 200)
const STRESS_SWAY: float = 12.0
const AB_BLOCK: int = 60
## Frames skipped after each switch, while the change settles.
const AB_SETTLE: int = 5

var _seconds: float = 40.0
## Opens the table and plays the Set, and keeps the frame times and node counts.
var _play: TablePlay = TablePlay.new()
var _stress: bool = false
## True for any of the A/B runs.
var _ab: bool = false
## What the A/B run switches: post_process, horror_intensity or table_light.
var _ab_key: String = "post_process"
var _gpu_on: PackedFloat64Array = []
var _gpu_off: PackedFloat64Array = []
var _ab_frame: int = 0
## The table light, for --light-ab.
var _light: PointLight2D = null
var _options: ToolOptions


func _initialize() -> void:
	_options = ToolOptions.new(USAGE)
	_seconds = _options.number("seconds", _seconds, 1.0)
	if _options.failed():
		quit(2)
		return
	_stress = _options.has("stress")
	_ab = _options.has("post-ab") or _options.has("horror-ab") or _options.has("light-ab")
	if _options.has("horror-ab"):
		_ab_key = "horror_intensity"
	if _options.has("light-ab"):
		_ab_key = "table_light"
	_run.call_deferred()


func _run() -> void:
	var start: Callable = func(app_node: Node) -> void: app_node.call("new_run", SEED)
	var table: Node = _play.open(self, start, _options)
	if _ab_key == "table_light":
		var atmosphere: Node = WalkBase.member(table, "_atmosphere")
		_light = atmosphere.call("light")
	if _ab:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await _play.warm_up(self)
	if _stress:
		await _run_stress(table)
		_report()
		quit(0)
		return
	var horror: bool = _ab_key == "horror_intensity"
	if horror:
		var dread: Object = WalkBase.member(table, "dread")
		dread.call("force", 90, 90, false, 9)
	await _play.play_set(self, _seconds, _sample_ab, not horror)
	_report()
	quit(0)


## Binds every deck card to a free pooled view on top of the table and sways them all.
func _run_stress(table: Node) -> void:
	# The pool and its views are reached by name: a card view names the screens' kit, which
	# needs the autoloads a --script tool compiles without.
	var pool: Object = WalkBase.member(table, "pool")
	var parent: Control = Control.new()
	table.add_child(parent)
	var views: Array[Control] = []
	for deck_id: int in Deck.SIZE:
		var view: Control = pool.call("acquire")
		if view == null:
			push_error("the pool ran out at card %d" % deck_id)
			return
		view.reparent(parent, false)
		view.call("bind", Deck.new().card(deck_id))
		views.append(view)
	print("visible_cards=%d pool_size=%d" % [views.size(), int(pool.call("size"))])
	var started: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() - started < int(_seconds * 1000.0):
		var phase: float = Time.get_ticks_msec() / 1000.0
		for index: int in views.size():
			@warning_ignore("integer_division")
			var cell: Vector2 = Vector2(index % STRESS_COLUMNS, index / STRESS_COLUMNS)
			var sway: Vector2 = Vector2(sin(phase + index), cos(phase + index)) * STRESS_SWAY
			views[index].position = STRESS_ORIGIN + cell * STRESS_STEP + sway
		await process_frame
		var now: int = Time.get_ticks_usec()
		_play.frame_ms.append((now - last) / 1000.0)
		last = now
		_sample_ab()
		_play.node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


## Times the GPU for this frame against whether the switched thing was on, then switches
## it at each block's end.
func _sample_ab() -> void:
	if not _ab:
		return
	_ab_frame += 1
	var in_block: int = _ab_frame % AB_BLOCK
	if in_block >= AB_SETTLE:
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(
			root.get_viewport_rid()
		)
		if _ab_on():
			_gpu_on.append(gpu)
		else:
			_gpu_off.append(gpu)
	if in_block == 0:
		_set_ab(not _ab_on())


func _report_ab() -> void:
	if not _ab:
		return
	_set_ab(true)
	var on: float = ToolStats.nearest_rank(ToolStats.sorted_of(_gpu_on), 50)
	var off: float = ToolStats.nearest_rank(ToolStats.sorted_of(_gpu_off), 50)
	print("gpu_samples_on=%d off=%d" % [_gpu_on.size(), _gpu_off.size()])
	print("gpu_median_ms_on=%.3f off=%.3f" % [on, off])
	print("%s_gpu_ms=%.3f" % [_ab_key, on - off])


# The Settings autoload is looked up at run time; a --script tool can't name it.
func _ab_on() -> bool:
	if _light != null:
		return _light.enabled
	return float(root.get_node("Settings").call("value", _ab_key)) > 0.5


func _set_ab(on: bool) -> void:
	if _light != null:
		_light.enabled = on
		return
	var value: Variant = on if _ab_key == "post_process" else (1.0 if on else 0.0)
	root.get_node("Settings").call("set_value", _ab_key, value)


func _report() -> void:
	var sorted: PackedFloat64Array = ToolStats.sorted_of(_play.frame_ms)
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var count: int = sorted.size()
	_report_ab()
	print("frames=%d" % count)
	print("mean_ms=%.2f" % (total / maxi(1, count)))
	print("median_ms=%.2f" % ToolStats.nearest_rank(sorted, 50))
	print("p99_ms=%.2f" % ToolStats.nearest_rank(sorted, 99))
	print("mean_fps=%.1f" % (1000.0 * count / maxf(1.0, total)))
	var counts: PackedInt64Array = _play.node_counts.duplicate()
	counts.sort()
	if counts.is_empty():
		print("nodes_during_rounds=none sampled")
	else:
		print("nodes_during_rounds_min=%d max=%d" % [counts[0], counts[-1]])

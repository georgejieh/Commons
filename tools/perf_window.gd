class_name PerfWindow
extends RefCounted
## The rows of the budget that need a real window and a GPU: startup to the title, frame
## time while a Set is played, nodes made during a round, and resident memory with the
## table open. Reaches the app by name at run time, because a --script tool compiles
## before the autoloads exist. Nothing here writes the player's save or profile: the
## run it plays is a demo started with no save and no profile.

const APP_SCENE: String = "res://ui/main.tscn"
const TITLE: String = "title"
const WINDOWLESS: String = "headless"
const NO_WINDOW: String = "needs a window and a GPU: run without --headless, with --windowed-rows"

var _tree: SceneTree
var _seed: int
var _seconds: float
var _options: ToolOptions


func _init(tree: SceneTree, first_seed: int, seconds: float, options: ToolOptions) -> void:
	_tree = tree
	_seed = first_seed
	_seconds = seconds
	_options = options


## Every windowed row not measured, each saying why.
static func unmeasured(why: String) -> Array[PerfRow]:
	return [
		PerfRow.unmeasured("Startup to title", PerfLimits.startup_budget(), why),
		PerfRow.unmeasured("Frame time during play", PerfLimits.frame_budget(), why),
		PerfRow.unmeasured("Nodes made during a round", "none", why),
		PerfRow.unmeasured("Resident memory, table open", PerfLimits.memory_budget(), why),
	]


## True when the tool runs with a window and a GPU to measure.
static func has_window() -> bool:
	return DisplayServer.get_name() != WINDOWLESS


## Measures every windowed row, in the report's order.
func measure() -> Array[PerfRow]:
	var rows: Array[PerfRow] = []
	rows.append(await _startup())
	var play: TablePlay = TablePlay.new()
	play.open(_tree, _start_demo, _options)
	await play.warm_up(_tree)
	await play.play_set(_tree, _seconds, Callable(), true)
	rows.append(_frame_row(play))
	rows.append(_node_row(play))
	rows.append(_memory_row(play.frame_ms.size()))
	play.app.queue_free()
	await _tree.process_frame
	return rows


## Starts the table's run as a demo, with no save and no profile to write.
func _start_demo(app: Node) -> void:
	var controller: Node = app.get("controller")
	var request: RunRequest = RunRequest.new(RunRequest.DEMO, _seed)
	request.writes_profile = false
	controller.call("start", request, null, null)


## Milliseconds from the engine's start (Time.get_ticks_msec counts from there) to the
## first frame drawn after the app shows its title screen, with the app's main scene loaded
## and added by this tool in place of the engine's own main-scene load.
func _startup() -> PerfRow:
	var scene: PackedScene = load(APP_SCENE)
	var app: Node = scene.instantiate()
	_tree.root.add_child(app)
	var switcher: Object = app.get("switcher")
	var opened: String = String(switcher.call("current_id"))
	if opened != TITLE:
		app.call("show_screen", TITLE, true)
	await RenderingServer.frame_post_draw
	var msec: int = Time.get_ticks_msec()
	var shown: String = String(switcher.call("current_id"))
	app.queue_free()
	await _tree.process_frame
	var note: String = (
		"engine start to the first frame drawn after the title is shown, through this tool's own"
		+ " load of the main scene; the time before the engine's clock starts, the engine's own"
		+ " main-scene load and a title screen still fading in are not in it"
	)
	if opened != TITLE:
		note += "; the app opened on %s, so the title was shown by the tool" % opened
	if shown != TITLE:
		return PerfRow.unmeasured(
			"Startup to title", PerfLimits.startup_budget(), "the title was not shown"
		)
	return PerfRow.judged(
		"Startup to title",
		PerfLimits.startup_budget(),
		"%d ms" % msec,
		msec < PerfLimits.STARTUP_MAX_MS,
		"1 start",
		note
	)


func _frame_row(play: TablePlay) -> PerfRow:
	var sorted: PackedFloat64Array = ToolStats.sorted_of(play.frame_ms)
	if sorted.is_empty():
		return PerfRow.unmeasured(
			"Frame time during play", PerfLimits.frame_budget(), "no frames drawn"
		)
	var p99: float = ToolStats.nearest_rank(sorted, 99)
	var measured: String = (
		"p50 %.2f ms, p99 %.2f ms, worst %.2f ms"
		% [ToolStats.nearest_rank(sorted, 50), p99, sorted[-1]]
	)
	return PerfRow.judged(
		"Frame time during play",
		PerfLimits.frame_budget(),
		measured,
		p99 < PerfLimits.FRAME_MAX_MS + PerfLimits.FRAME_SLACK_MS,
		"%d frames over %.0f s of a bot-played Set" % [sorted.size(), _seconds],
		(
			"judged on p99 with %.1f ms of frame-clock slack; at the table's real pacing"
			% PerfLimits.FRAME_SLACK_MS
		)
	)


func _node_row(play: TablePlay) -> PerfRow:
	var counts: PackedInt64Array = play.node_counts.duplicate()
	counts.sort()
	if counts.is_empty():
		return PerfRow.unmeasured("Nodes made during a round", "none", "no round was in play")
	return PerfRow.judged(
		"Nodes made during a round",
		"none",
		"node count min %d, max %d" % [counts[0], counts[-1]],
		counts[0] == counts[-1],
		"%d frames inside a round" % counts.size()
	)


## Resident memory after a Set at the table, with what the engine itself reports beside it.
func _memory_row(frames: int) -> PerfRow:
	var resident: int = PerfMemory.resident_bytes()
	var engine: String = (
		"static %s, texture %s, video %s"
		% [
			PerfMemory.megabytes(PerfMemory.static_bytes()),
			PerfMemory.megabytes(PerfMemory.texture_bytes()),
			PerfMemory.megabytes(PerfMemory.video_bytes()),
		]
	)
	if resident == PerfMemory.NOT_AVAILABLE:
		return PerfRow.new(
			"Resident memory, table open",
			PerfLimits.memory_budget(),
			"resident memory was not measured on this platform; engine reports %s" % engine,
			PerfRow.Verdict.NOT_MEASURED,
			"",
			"no call gives the process's resident set here"
		)
	return PerfRow.judged(
		"Resident memory, table open",
		PerfLimits.memory_budget(),
		"resident %s" % PerfMemory.megabytes(resident),
		resident < PerfLimits.MEMORY_MAX_BYTES,
		"once, after %d frames of play" % frames,
		"%s; resident is the process's working set from the operating system" % engine
	)

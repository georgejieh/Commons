extends SceneTree
## Measures the texture memory of a full table scene (P3C.4): a seeded run on the table
## with every Cadre slot filled, read from the profiler's texture-memory monitor. Exits
## 1 when it is over budget. Needs a real renderer, not --headless; it runs in the cloud
## playtest so no window opens locally:
##   godot --path . --script res://tools/texture_budget.gd -- [--budget-mb 128]
## Development only; tools/ never ships.

const SEED: int = 4242
const SETTLE_FRAMES: int = 30
const MB: float = 1024.0 * 1024.0

var _budget_mb: float = 128.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--budget-mb")
	if at >= 0 and at + 1 < args.size():
		_budget_mb = args[at + 1].to_float()
	_run.call_deferred()


func _run() -> void:
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	app.call("new_run", SEED)
	var table: Node = app.call("show_screen", "table", true)
	var board: Node = table.get("_board")
	var pool: Resource = load("res://data/run/cadre_pool.tres")
	var definitions: Array = pool.get("cadres")
	var cadres: Array[String] = []
	for definition: Resource in definitions:
		cadres.append(String(definition.get("id")))
	_show_all_cadres(board, cadres)
	for _frame: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var used: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB
	var verdict: String = "PASS" if used <= _budget_mb else "OVER"
	print("texture memory: %.1f MB of %.0f MB budget, %s" % [used, _budget_mb, verdict])
	quit(0 if used <= _budget_mb else 1)


## Puts every Cadre's art on the notice board, as a full board would show it.
func _show_all_cadres(board: Node, cadres: Array[String]) -> void:
	var pictures: Array = board.get("_pictures")
	var kit: GDScript = load("res://ui/screens/screen_kit.gd")
	for index: int in mini(pictures.size(), cadres.size()):
		var picture: TextureRect = pictures[index]
		picture.texture = kit.call("cadre_art", cadres[index])

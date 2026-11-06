extends SceneTree
## Measures the texture memory of a full table scene (P3C.4): a seeded run on the table
## with every Cadre slot filled and all 54 card faces shown (so every court and joker
## picture is loaded), at corruption stages 0, 4 and 9 in turn, reading the profiler's
## texture-memory monitor each time. Stage art loads on demand, so this also catches
## art from an earlier stage that stays resident. Reports the peak and exits 1 when it
## is over budget. Needs a real renderer, not --headless; it runs in the cloud playtest
## so no window opens locally:
##   godot --path . --script res://tools/texture_budget.gd -- [--budget-mb 128]
## Development only; tools/ never ships.

const SEED: int = 4242
const SETTLE_FRAMES: int = 30
const MB: float = 1024.0 * 1024.0
const STAGES: Array[int] = [0, 4, 9]
const DECK_SIZE: int = 54

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
	var peak: float = 0.0
	for stage: int in STAGES:
		ArtStages.stage_override = stage
		var table: Node = app.call("show_screen", "table", true)
		_show_all_cadres(table.get("_board"))
		_show_all_cards(table)
		for _frame: int in SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var used: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB
		print("stage %d texture memory: %.1f MB" % [stage, used])
		peak = maxf(peak, used)
	var verdict: String = "PASS" if peak <= _budget_mb else "OVER"
	print("texture memory: %.1f MB peak of %.0f MB budget, %s" % [peak, _budget_mb, verdict])
	quit(0 if peak <= _budget_mb else 1)


## Puts every Cadre's art on the notice board, as a full board would show it.
func _show_all_cadres(board: Node) -> void:
	var pool: CadrePool = load("res://data/run/cadre_pool.tres")
	var pictures: Array[TextureRect] = []
	pictures.assign(board.get("_pictures"))
	var kit: GDScript = load("res://ui/screens/screen_kit.gd")
	for index: int in mini(pictures.size(), pool.cadres.size()):
		pictures[index].texture = kit.call("cadre_art", pool.cadres[index].id)


## Binds the whole deck to free views from the table's own pool.
func _show_all_cards(table: Node) -> void:
	var pool: CardPool = table.get("_pool")
	for deck_id: int in DECK_SIZE:
		var view: CardView = pool.acquire()
		if view == null:
			return
		view.bind(CardInstance.from_deck_id(deck_id))

extends SceneTree
## Renders the table in each of the seven board states, the last corruption stage, and
## the clean board at every stage, then the four slow horrors with both meters high at
## stages 0, 4 and 9: the eyes on the seats' card backs turned toward a pointer at the
## hand, the trembling hand twice a moment apart, the roster's names, and both villagers
## speaking; and the turn's frame on a seat. One screenshot per state, for checking by
## eye. Needs a real window for its pictures; with --headless it names each frame:
##   godot --path . --script res://tools/board_states.gd -- --out reports/board_states
## Development only; tools/ never ships.

const USAGE: String = "board_states.gd -- [--out DIR] [--profile NAME]"
const DEFAULT_OUT: String = "reports/board_states"
const SEED: int = 4242
const SETTLE_FRAMES: int = 40
const LAST_STAGE: int = 9
const EFFECT_STAGES: Array[int] = [0, 4, LAST_STAGE]
## Where the pointer rests for the eyes to look at: over the hand, low and left.
const POINTER_AT: Vector2 = Vector2(300, 940)
## Seconds between the two frames of the trembling hand.
const TREMBLE_GAP: float = 0.07

var _out: String
var _options: ToolOptions
## False once a picture could not be saved, which fails the run.
var _saved: bool = true


func _initialize() -> void:
	_options = ToolOptions.new(USAGE)
	_out = _options.path("out", DEFAULT_OUT)
	if _options.failed():
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	WalkProfile.keep_run(root, "board_states", _options)
	# Loaded at run time: the demo names autoloads, which a --script tool can't see.
	var scene: PackedScene = load("res://ui/main.tscn")
	var app: Node = scene.instantiate()
	root.add_child(app)
	app.call("new_run", SEED)
	var table: Node = app.call("show_screen", "table", true)
	await _settle()
	var dread: Node = WalkBase.member(table, "dread")
	var states: Dictionary = load("res://game/horror/board_state.gd").get("BOARD_STATES")
	for state: String in states:
		var inputs: Vector3 = states[state]
		dread.call("force", int(inputs.x), int(inputs.y), inputs.z > 0.0, 0)
		await _settle()
		await _shot(state)
	dread.call("force", 10, 10, false, LAST_STAGE)
	await _settle()
	await _shot("corruption_stage_%d" % LAST_STAGE)
	# The clean board at every corruption stage, to check the stage art by eye.
	for stage: int in LAST_STAGE + 1:
		dread.call("force", 0, 0, false, stage)
		await _settle()
		await _shot("clean_stage_%d" % stage)
	await _effect_frames(table, dread)
	quit(0 if _saved else 1)


## The slow horrors at three stages, then the turn's frame on the right seat.
func _effect_frames(table: Node, dread: Node) -> void:
	var speech: Object = WalkBase.member(table, "speech")
	speech.set("hurrying", true)
	Input.warp_mouse(POINTER_AT)
	for stage: int in EFFECT_STAGES:
		dread.call("force", 100, 100, false, stage)
		speech.call("say", 1, "pass")
		speech.call("say", 2, "cards_left", {"count": 3})
		await _settle()
		await _shot("horrors_stage_%d" % stage)
		await create_timer(TREMBLE_GAP).timeout
		await _shot("horrors_stage_%d_later" % stage)
	dread.call("force", 10, 10, false, 0)
	var turn: Object = WalkBase.member(table, "turn")
	turn.call("mark", 1)
	await _settle()
	await _shot("turn_mark")


func _settle() -> void:
	for _frame: int in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	print("FRAME %s" % name)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_saved = ToolFiles.save_png(image, _out.path_join(name + ".png")) and _saved
